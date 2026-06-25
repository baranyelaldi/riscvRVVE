# =============================================================
# histogram.s — RVV-vectorized histogram (4-bin)
# Counts how many times each value 0..3 appears in a byte buffer.
#
# Strategy (the "match-and-count" idiom that fits a core with no
# scatter/gather): for each bin value b, compare every input byte
# against b (vmseq.vx) producing a mask, then count the set bits
# (vcpop.m). That popcount IS the number of occurrences of b.
#
#   for b in 0..numbins-1:
#       mask  = (input == b)        # vmseq.vx
#       count = popcount(mask)      # vcpop.m
#       hist[b] = count
#
# Test input: 16 bytes laid out as
#   {0,0, 1,1,1,1, 2,2,2,2,2,2, 3,3,3,3}
#   -> hist[0]=2, hist[1]=4, hist[2]=6, hist[3]=4   (sum = 16)
#
# 16 bytes = exactly VLMAX at e8, so one vle8 covers the whole input.
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup
    # -----------------------------------------------------------
    la      a0, data            # a0 = input buffer
    li      a1, 0x4000          # a1 = histogram output base
    li      a2, 0               # a2 = bin value b (also loop counter)
    li      a3, 4               # a3 = number of bins

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle           # s0 = start cycle

    # -----------------------------------------------------------
    # Load the entire 16-byte input once (reused for every bin)
    # -----------------------------------------------------------
    vsetvli t0, x0, e8, m1      # vl = VLMAX = 16
    vle8.v  v1, (a0)            # v1 = all 16 input bytes

# ===============================================================
# BIN LOOP — one pass per histogram bin
# ===============================================================
bin_loop:
    # Mask: v2[i] = (input[i] == b)
    vmseq.vx v2, v1, a2

    # Count matches = popcount of mask bits within vl
    vcpop.m t1, v2

    # hist[b] = count
    sw      t1, 0(a1)
    addi    a1, a1, 4           # next hist slot

    # b++; loop while b < numbins
    addi    a2, a2, 1
    blt     a2, a3, bin_loop

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
# Data — 16-byte input
# Bytes: 0,0, 1,1,1,1, 2,2,2,2,2,2, 3,3,3,3
# As little-endian words:
#   word0 = bytes {0,0,1,1}      = 0x01010000
#   word1 = bytes {1,1,2,2}      = 0x02020101
#   word2 = bytes {2,2,2,2}      = 0x02020202
#   word3 = bytes {3,3,3,3}      = 0x03030303
# =============================================================
.balign 4
data:
    .word 0x01010000
    .word 0x02020101
    .word 0x02020202
    .word 0x03030303
