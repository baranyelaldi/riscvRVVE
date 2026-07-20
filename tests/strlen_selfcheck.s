# =============================================================
# strlen_selfcheck.s — self-checking copy of strlen.s
# Kernel unchanged; self-check appended AFTER the cycle snapshot.
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Expected: length("Hello RVVE vectors!") = 19 = 0x13
# =============================================================
.text
.global _start
_start:
    la      a0, str
    li      a1, 0

    csrr    s0, cycle

strlen_loop:
    vsetvli t0, x0, e8, m1
    vle8.v  v1, (a0)
    vmseq.vx v2, v1, x0
    vfirst.m t1, v2
    bgez    t1, found
    add     a1, a1, t0
    add     a0, a0, t0
    j       strlen_loop
found:
    add     a1, a1, t1

    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x4000
    sw      a1, 0(t0)           # ram[0x4000] = length
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[0x9000] = kernel cycles

    # ===== SELF-CHECK (after snapshot) =====
    la      t0, expected
    li      t1, 0x4000
    li      t2, 1               # 1 result word
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
str:
    .asciz "Hello RVVE vectors!"
    .zero  16

.balign 4
expected:
    .word 0x13                  # strlen = 19
