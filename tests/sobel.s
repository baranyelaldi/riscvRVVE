# =============================================================
# sobel.s — RVV-vectorized 2D Sobel horizontal gradient (Gx)
# The conv2d-class kernel used by peer cores (Vicuna, Spatz).
#
# Sobel-Gx is a 3x3 convolution with kernel:
#       [ -1  0  +1 ]
#  Gx = [ -2  0  +2 ]
#       [ -1  0  +1 ]
#
# For each output pixel it computes (right column weighted sum)
# minus (left column weighted sum); the center column has weight 0:
#
#   Gx[c] = ( I[r-1][c+1] + 2*I[r][c+1] + I[r+1][c+1] )
#         - ( I[r-1][c-1] + 2*I[r][c-1] + I[r+1][c-1] )
#
# We vectorize ACROSS COLUMNS: for the three input rows we take two
# "views" 2 columns apart (the c-1 and c+1 neighbours) using plain
# unit-stride loads, weight the middle row by 2 with vmacc.vx, and
# subtract left from right with vsub.vv.
#
# Image is padded with a zero column border so the c-1 / c+1 views
# are always in valid memory (no boundary special case).
#
# Input (3 rows, each padded to 6 cols, real data in cols 1..4):
#   rowA (r-1): 0  10  20  30  40 0
#   rowB (r):   0  50  60  70  80 0
#   rowC (r+1): 0  90 100 110 120 0
#
# Output Gx for the 4 real columns:
#   left_sum  = rowA[0..3] + 2*rowB[0..3] + rowC[0..3] = [0,200,240,280]
#   right_sum = rowA[2..5] + 2*rowB[2..5] + rowC[2..5] = [240,280,320,0]
#   Gx = right - left = [240, 80, 80, -280]
#                     = [0xF0, 0x50, 0x50, 0xFFFFFEE8]
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup — one pointer per input row
    # -----------------------------------------------------------
    la      a0, rowA            # &I[r-1][0]
    la      a1, rowB            # &I[r][0]
    la      a2, rowC            # &I[r+1][0]
    li      a3, 0x4000          # output base

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle

    li      t0, 4               # 4 output columns = VLMAX at e32
    vsetvli zero, t0, e32, m1

    # -----------------------------------------------------------
    # LEFT column sum (the c-1 neighbours): padded index 0..3
    #   left = rowA[0..3] + 2*rowB[0..3] + rowC[0..3]
    # -----------------------------------------------------------
    vle32.v v1, (a0)            # vA_left
    vle32.v v2, (a1)            # vB_left
    vle32.v v3, (a2)            # vC_left
    vadd.vv v4, v1, v3          # v4 = vA_left + vC_left
    li      t0, 2
    vmacc.vx v4, t0, v2         # v4 += 2 * vB_left  -> left_sum

    # -----------------------------------------------------------
    # RIGHT column sum (the c+1 neighbours): padded index 2..5
    #   right = rowA[2..5] + 2*rowB[2..5] + rowC[2..5]
    # The +8 byte offset shifts the view two columns right.
    # -----------------------------------------------------------
    addi    t1, a0, 8
    vle32.v v5, (t1)            # vA_right
    addi    t1, a1, 8
    vle32.v v6, (t1)            # vB_right
    addi    t1, a2, 8
    vle32.v v7, (t1)            # vC_right
    vadd.vv v8, v5, v7          # v8 = vA_right + vC_right
    li      t0, 2
    vmacc.vx v8, t0, v6         # v8 += 2 * vB_right -> right_sum

    # -----------------------------------------------------------
    # Gx = right_sum - left_sum   (vsub computes vs2 - vs1)
    # -----------------------------------------------------------
    vsub.vv v9, v8, v4
    vse32.v v9, (a3)            # store Gx[0..3]

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
# Data — 3 image rows, each padded to 6 columns with a zero border
# Real pixels live in columns 1..4.
# =============================================================
.balign 4
rowA:
    .word 0, 10, 20, 30, 40, 0
.balign 4
rowB:
    .word 0, 50, 60, 70, 80, 0
.balign 4
rowC:
    .word 0, 90, 100, 110, 120, 0
