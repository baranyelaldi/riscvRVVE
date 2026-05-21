.text
.global _start
_start:
    la      t0, data_A
    la      t1, data_B
    li      t2, 0x4000              # C base in TCM

    vmv.v.x v0, x0                  # v0 = {0,0,0,0} accumulator zero

    li      a2, 0
    li      a3, 4

row_loop:
    vle32.v v1, (t0)
    mv      a4, t1
    li      a5, 0

col_loop:
    vle32.v v2, (a4)
    vmul.vv    v3, v1, v2
    vredsum.vs v4, v3, v0
    vmv.x.s    a1, v4
    sw      a1, 0(t2)

    addi    a4, a4, 16
    addi    t2, t2, 4
    addi    a5, a5, 1
    blt     a5, a3, col_loop

    addi    t0, t0, 16
    addi    a2, a2, 1
    blt     a2, a3, row_loop

    # Check all 16 results against expected values
    li      s0, 0x4000
    li      s1, 16
    la      s2, expected

check_loop:
    lw      a0, 0(s0)
    lw      a1, 0(s2)
    bne     a0, a1, fail

    addi    s0, s0, 4
    addi    s2, s2, 4
    addi    s1, s1, -1
    bnez    s1, check_loop

    la      a0, msg_pass
    call    uart_print_str
    j       done

fail:
    la      a0, msg_fail
    call    uart_print_str
    lw      a0, 0(s0)               # got
    call    uart_print_hex
    lw      a0, 0(s2)               # expected
    call    uart_print_hex

done:
1:  j       1b

msg_pass:   .asciz "PASS\n"
msg_fail:   .asciz "FAIL\n"

.balign 4
expected:
    .word 90,  100, 110, 120
    .word 202, 228, 254, 280
    .word 314, 356, 398, 440
    .word 426, 484, 542, 600

.balign 4
data_A:                             # row-major 4x4
    .word 1, 2, 3, 4
    .word 5, 6, 7, 8
    .word 9, 10, 11, 12
    .word 13, 14, 15, 16

.balign 4
data_B:                             # column-major 4x4 (= A^T)
    .word 1, 5,  9, 13
    .word 2, 6, 10, 14
    .word 3, 7, 11, 15
    .word 4, 8, 12, 16

.include "uart_lib.s"
