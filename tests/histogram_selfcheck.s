# =============================================================
# histogram_selfcheck.s — self-checking copy of histogram.s
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Expected hist[0..3] = {2, 4, 6, 4}
# =============================================================
.text
.global _start
_start:
    la      a0, data
    li      a1, 0x4000
    li      a2, 0
    li      a3, 4

    csrr    s0, cycle
    vsetvli t0, x0, e8, m1
    vle8.v  v1, (a0)
bin_loop:
    vmseq.vx v2, v1, a2
    vcpop.m t1, v2
    sw      t1, 0(a1)
    addi    a1, a1, 4
    addi    a2, a2, 1
    blt     a2, a3, bin_loop

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
data:
    .word 0x01010000
    .word 0x02020101
    .word 0x02020202
    .word 0x03030303

.balign 4
expected:
    .word 2, 4, 6, 4
