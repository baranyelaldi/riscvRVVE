.text
.global _start
_start:
    # Setup mem: {3, 5, 7, 5}
    li      t0, 0x2000
    li      t1, 3;  sw t1, 0(t0)
    li      t1, 5;  sw t1, 4(t0)
    li      t1, 7;  sw t1, 8(t0)
    li      t1, 5;  sw t1, 12(t0)

    vle32.v v1, (t0)                # v1 = {3, 5, 7, 5}

    # Generate three test masks with different properties
    vmseq.vi v2, v1, 5              # v2 = 0xA (two set bits at positions 1, 3)
    vmseq.vi v3, v1, 8              # v3 = 0x0 (no element equals 8)
    vmseq.vi v4, v1, 3              # v4 = 0x1 (one set bit at position 0)

    # vcpop: count set bits
    vcpop.m  t2, v2                 # t2 = popcount(0xA) = 2
    vcpop.m  t3, v3                 # t3 = popcount(0x0) = 0
    vcpop.m  t4, v4                 # t4 = popcount(0x1) = 1

    # vfirst: index of first set bit (or -1 = 0xFFFFFFFF)
    vfirst.m t5, v2                 # t5 = first(0xA) = 1 (bits 1,3 set; lowest = 1)
    vfirst.m t6, v3                 # t6 = first(0x0) = -1 = 0xFFFFFFFF
    vfirst.m a0, v4                 # a0 = first(0x1) = 0

    # Exit — inspect scalar regs in REGISTERS group
    li      a1, 0
    csrw    dscratch, a1
1:  j       1b
