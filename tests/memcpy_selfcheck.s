# =============================================================
# memcpy_selfcheck.s — self-checking copy of memcpy.s
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Checks the 5 copied words + the untouched sentinel word after them
# (proves the copy is correct AND did not overrun 20 bytes).
# =============================================================
.text
.global _start
_start:
    # source pattern at 0x2000
    li      t0, 0x2000
    li      t1, 0x13121110; sw t1, 0(t0)
    li      t1, 0x17161514; sw t1, 4(t0)
    li      t1, 0x1B1A1918; sw t1, 8(t0)
    li      t1, 0x1F1E1D1C; sw t1, 12(t0)
    li      t1, 0x23222120; sw t1, 16(t0)

    # pre-seed dst at 0x4000 with 0xFF sentinel
    li      t2, 0x4000
    li      t1, 0xFFFFFFFF
    sw      t1, 0(t2)
    sw      t1, 4(t2)
    sw      t1, 8(t2)
    sw      t1, 12(t2)
    sw      t1, 16(t2)
    sw      t1, 20(t2)

    li      a0, 0x2000          # src
    li      a1, 0x4000          # dst
    li      a2, 20              # n = 20 bytes

    csrr    s0, cycle
memcpy_loop:
    vsetvli a3, a2, e8, m1
    vle8.v  v1, (a0)
    vse8.v  v1, (a1)
    add     a0, a0, a3
    add     a1, a1, a3
    sub     a2, a2, a3
    bnez    a2, memcpy_loop

    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)

    # ===== SELF-CHECK: 5 copied words + 1 untouched sentinel =====
    la      t0, expected
    li      t1, 0x4000
    li      t2, 6
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
expected:
    .word 0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120
    .word 0xFFFFFFFF                # sentinel: bytes 20..23 untouched
