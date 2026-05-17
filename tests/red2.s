.section .text
.globl _start
_start:
    vmv.v.x v0, x0                  # v0 = {0,0,0,0}

    # ---- First reduction ----
    li      t0, 10
    vmv.v.x v3, t0                  # v3 = {10,10,10,10}
    vredsum.vs v4, v3, v0           # v4[0] = 40 = 0x28
    li      t1, 0x4000
    vse32.v v4, (t1)

    # ---- Second reduction (this is the failing case in matvec) ----
    li      t0, 7
    vmv.v.x v3, t0                  # v3 = {7,7,7,7}
    vredsum.vs v4, v3, v0           # v4[0] = 28 = 0x1C
    li      t1, 0x4010
    vse32.v v4, (t1)

    li      a0, 0
    csrw    dscratch, a0
1:  j 1b
