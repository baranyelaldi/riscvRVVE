.text
.global _start
_start:
    li      t0, 0x2000
    li      t1, 0xDEADBEEF
    sw      t1, 0(t0)            # mem[0x2000] = DEADBEEF

    vle32.v v2, (t0)             # v2 = {DEADBEEF, 0, 0, 0}
    vmv.x.s t3, v2               # t3 should be 0xDEADBEEF

    li      t4, 0x4000
    sw      t3, 0(t4)            # ram[4096] = DEADBEEF

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
