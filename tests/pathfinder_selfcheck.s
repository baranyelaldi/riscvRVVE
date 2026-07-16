# =============================================================
# pathfinder_selfcheck.s — self-checking copy of pathfinder.s
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Expected dst[0..3] = {6, 7, 6, 7}
# =============================================================
.text
.global _start
_start:
    la      a0, src_padded
    la      a1, grid
    li      a2, 0x4000
    li      t0, 4

    csrr    s0, cycle
    vsetvli zero, t0, e32, m1

    vle32.v v1, (a0)
    addi    t1, a0, 4
    vle32.v v2, (t1)
    addi    t2, a0, 8
    vle32.v v3, (t2)
    vminu.vv v4, v2, v3
    vminu.vv v4, v4, v1
    vle32.v v5, (a1)
    vadd.vv v6, v5, v4
    vse32.v v6, (a2)

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
src_padded:
    .word 0xFFFFFFFF, 10, 5, 8, 3, 0xFFFFFFFF
.balign 4
grid:
    .word 1, 2, 3, 4

.balign 4
expected:
    .word 6, 7, 6, 7
