# =============================================================
# pathfinder.s — RVV-vectorized Pathfinder (one DP step)
# Source: Rodinia / RiVec "pathfinder" dynamic-programming kernel.
#
# Pathfinder finds the minimum-cost path down a grid. Each cell's
# new cost = its own grid weight + the cheapest of the three cells
# above it (up-left, up, up-right):
#
#   dst[n] = grid[n] + min( src[n-1], src[n], src[n+1] )
#
# The "min of 3 neighbours" is the kernel's signature operation.
# We vectorize it with two vminu.vv (unsigned min) over three
# sliding windows of the previous row, then vadd the grid weights.
#
# Boundary trick: pad the previous row with INF (0xFFFFFFFF) at
# both ends. Since vminu is unsigned, INF is the max value and is
# always discarded by min — so edge cells naturally see only their
# valid neighbours, and the uniform formula needs no special case.
#
# This file does ONE row transition (the core DP step). The full
# benchmark repeats this row-by-row, swapping src/dst each step.
#
# Test data:
#   src (prev row costs) = [10, 5, 8, 3]   (padded: [INF,10,5,8,3,INF])
#   grid (this row)      = [1, 2, 3, 4]
# Expected dst:
#   dst[0] = 1 + min(INF,10,5)  = 1 + 5 = 6
#   dst[1] = 2 + min(10,5,8)    = 2 + 5 = 7
#   dst[2] = 3 + min(5,8,3)     = 3 + 3 = 6
#   dst[3] = 4 + min(8,3,INF)   = 4 + 3 = 7
#   => dst = [6, 7, 6, 7]
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup
    # -----------------------------------------------------------
    la      a0, src_padded      # a0 = &padded previous row
    la      a1, grid            # a1 = &current row weights
    li      a2, 0x4000          # a2 = dst output base
    li      t0, 4               # cols = 4 (= VLMAX at e32, single chunk)

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle

    # vl = 4
    vsetvli zero, t0, e32, m1

    # -----------------------------------------------------------
    # Three sliding windows over the padded previous row.
    # src_padded layout:  [ INF, s0, s1, s2, s3, INF ]
    #   v_left   = src_padded[0..3] = [INF, s0, s1, s2]
    #   v_center = src_padded[1..4] = [s0, s1, s2, s3]
    #   v_right  = src_padded[2..5] = [s1, s2, s3, INF]
    # The element at column n sees neighbours via these three views.
    # -----------------------------------------------------------
    vle32.v v1, (a0)            # v_left
    addi    t1, a0, 4
    vle32.v v2, (t1)            # v_center
    addi    t2, a0, 8
    vle32.v v3, (t2)            # v_right

    # -----------------------------------------------------------
    # min of the three neighbours (unsigned)
    # -----------------------------------------------------------
    vminu.vv v4, v2, v3         # v4 = min(center, right)
    vminu.vv v4, v4, v1         # v4 = min(v4, left) = min of all three

    # -----------------------------------------------------------
    # Add this row's grid weights
    # -----------------------------------------------------------
    vle32.v v5, (a1)            # v5 = grid weights
    vadd.vv v6, v5, v4          # v6 = grid + min3 = new row costs

    # -----------------------------------------------------------
    # Store result row
    # -----------------------------------------------------------
    vse32.v v6, (a2)            # dst[0..3]

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot after kernel, store at 0x9000
    # -----------------------------------------------------------
    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[9216] = cycle count

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# =============================================================
# Data
# src_padded: previous-row costs with INF halo at both ends
# grid:       current-row weights
# =============================================================
.balign 4
src_padded:
    .word 0xFFFFFFFF, 10, 5, 8, 3, 0xFFFFFFFF

.balign 4
grid:
    .word 1, 2, 3, 4
