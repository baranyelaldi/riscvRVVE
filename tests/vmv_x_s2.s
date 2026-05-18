.text
.global _start
_start:
    li      t0, 0x4000
    li      t1, 0xDEADBEEF
    sw      t1, 0(t0)            # mem[0x2000] = DEADBEEF
    vle32.v v2, (t0)             # v2 = {DEADBEEF, 0, 0, 0}
    vmv.x.s t3, v2

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
