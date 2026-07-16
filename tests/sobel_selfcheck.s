# =============================================================
# sobel_selfcheck.s — self-checking copy of sobel.s (Sobel-Gx)
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Expected Gx[0..3] = {0xF0, 0x50, 0x50, 0xFFFFFEE8}  (240, 80, 80, -280)
# =============================================================
.text
.global _start
_start:
    la      a0, rowA
    la      a1, rowB
    la      a2, rowC
    li      a3, 0x4000

    csrr    s0, cycle
    li      t0, 4
    vsetvli zero, t0, e32, m1

    vle32.v v1, (a0)
    vle32.v v2, (a1)
    vle32.v v3, (a2)
    vadd.vv v4, v1, v3
    li      t0, 2
    vmacc.vx v4, t0, v2

    addi    t1, a0, 8
    vle32.v v5, (t1)
    addi    t1, a1, 8
    vle32.v v6, (t1)
    addi    t1, a2, 8
    vle32.v v7, (t1)
    vadd.vv v8, v5, v7
    li      t0, 2
    vmacc.vx v8, t0, v6

    vsub.vv v9, v8, v4
    vse32.v v9, (a3)

    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)

    # ===== SELF-CHECK =====
    la      t0, expected
    li      t1, 0x4000
    li      t2, 4
    li      t3, 0
check_loop:
    lw      t4, 0(t1)
    lw      t5, 0(t0)
    bne     t4, t5, check_fail
    addi    t0, t0, 4
    addi    t1, t1, 4
    addi    t3, t3, 1
    blt     t3, t2, check_loop
check_pass:
    li      t6, 0x600D600D
    j       check_report
check_fail:
    li      t5, 0xBAD00000
    or      t6, t5, t3
check_report:
    li      t0, 0xA000
    sw      t6, 0(t0)

    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

.balign 4
rowA:
    .word 0, 10, 20, 30, 40, 0
.balign 4
rowB:
    .word 0, 50, 60, 70, 80, 0
.balign 4
rowC:
    .word 0, 90, 100, 110, 120, 0

.balign 4
expected:
    .word 0xF0, 0x50, 0x50, 0xFFFFFEE8
