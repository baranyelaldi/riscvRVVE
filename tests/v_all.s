.section .text
.globl _start
_start:
    # Scalar regs for .vx variants
    li      t0, 5
    li      t1, 100

    nop

    # === OPIVV (funct3=000) — vector-vector ===
    vadd.vv    v1,  v2, v0
    vsub.vv    v3,  v4, v0
    vminu.vv   v5,  v6, v0
    vmaxu.vv   v7,  v8, v0

    nop

    # === OPIVX (funct3=100) — vector-scalar reg ===
    vadd.vx    v9,  v2, t0
    vsub.vx    v10, v4, t0
    vrsub.vx   v11, v6, t1
    vminu.vx   v12, v8, t0
    vmaxu.vx   v13, v10, t1

    nop

    # === OPIVI (funct3=011) — vector-immediate ===
    vadd.vi    v14, v2, 7
    vrsub.vi   v15, v4, -8

    nop

    # === OPMVV (funct3=010) — multiply + reduction ===
    vmul.vv    v16, v2, v0
    vredsum.vs v17, v2, v0

    nop

    # === Clean exit ===
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b
