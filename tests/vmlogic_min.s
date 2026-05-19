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

    # Generate two masks
    vmseq.vi v2, v1, 5              # v2 = {3==5, 5==5, 7==5, 5==5} = 0b1010 = 0xA
    vmseq.vi v3, v1, 3              # v3 = {3==3, 5==3, 7==3, 5==3} = 0b0001 = 0x1

    # Mask logicals
    vmand.mm  v4, v2, v3            # v4 = 0xA & 0x1 = 0x0
    vmor.mm   v5, v2, v3            # v5 = 0xA | 0x1 = 0xB
    vmxor.mm  v6, v2, v3            # v6 = 0xA ^ 0x1 = 0xB
    vmnand.mm v7, v2, v3            # v7 = ~(0xA & 0x1) & 0xF = ~0 & 0xF = 0xF

    # Exit — check vregs_q[4..7]
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
