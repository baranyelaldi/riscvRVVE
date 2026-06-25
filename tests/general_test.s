.text
.global _start

# Stack at 0x3F00 — safely between code (~0x2000) and scratch (0x4000)
_start:
    li      sp, 0x3F00

    call    run_saxpy
    la      a1, msg_saxpy
    call    print_result

    call    run_dot
    la      a1, msg_dot
    call    print_result

    call    run_matvec
    la      a1, msg_matvec
    call    print_result

    call    run_matmul
    la      a1, msg_matmul
    call    print_result

    la      a0, msg_done
    call    uart_print_str

1:  j       1b

# -----------------------------------------------------------------------
# print_result: print "<name>: PASS\n" or "<name>: FAIL\n"
# a0 = 0 (pass) / 1 (fail),  a1 = pointer to test name string
# -----------------------------------------------------------------------
print_result:
    addi    sp, sp, -8
    sw      ra, 0(sp)
    sw      a0, 4(sp)
    mv      a0, a1
    call    uart_print_str
    lw      t0, 4(sp)
    beqz    t0, .Lpr_pass
    la      a0, msg_fail
    j       .Lpr_print
.Lpr_pass:
    la      a0, msg_pass
.Lpr_print:
    call    uart_print_str
    lw      ra, 0(sp)
    addi    sp, sp, 8
    ret

# -----------------------------------------------------------------------
# run_saxpy: y = a*x + y,  a=5, x=[1,2,3,4], y=[10,20,30,40]
# Expected at 0x4000: [15, 30, 45, 60]
# -----------------------------------------------------------------------
run_saxpy:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    li      t3, 5
    la      t0, saxpy_x
    vle32.v v1, (t0)
    la      t1, saxpy_y
    vle32.v v2, (t1)
    vmv.v.x v3, t3
    vmul.vv v4, v3, v1
    vadd.vv v5, v4, v2
    li      t2, 0x4000
    vse32.v v5, (t2)

    lw      t0, 0(t2);  li t1, 15;  bne t0, t1, .Lsaxpy_fail
    lw      t0, 4(t2);  li t1, 30;  bne t0, t1, .Lsaxpy_fail
    lw      t0, 8(t2);  li t1, 45;  bne t0, t1, .Lsaxpy_fail
    lw      t0, 12(t2); li t1, 60;  bne t0, t1, .Lsaxpy_fail
    li      a0, 0;  j .Lsaxpy_done
.Lsaxpy_fail:
    li      a0, 1
.Lsaxpy_done:
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# -----------------------------------------------------------------------
# run_dot: a·b,  a=[1,2,3,4], b=[5,6,7,8]
# Expected at 0x4000[0]: 70
# -----------------------------------------------------------------------
run_dot:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    la      t0, dot_a
    vle32.v v1, (t0)
    la      t1, dot_b
    vle32.v v2, (t1)
    vmul.vv    v3, v1, v2
    vmv.v.x    v4, x0
    vredsum.vs v5, v3, v4
    li      t2, 0x4000
    vse32.v v5, (t2)

    lw      t0, 0(t2)
    li      t1, 70
    li      a0, 1
    bne     t0, t1, .Ldot_done
    li      a0, 0
.Ldot_done:
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# -----------------------------------------------------------------------
# run_matvec: y = A*x,  x=[1,2,3,4]
# A = [[10,20,30,40],[5,6,7,8],[9,10,11,12],[13,14,15,16]]
# Expected y[0..3]: [300, 70, 110, 150] at 0x4000, 0x4010, 0x4020, 0x4030
# -----------------------------------------------------------------------
run_matvec:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    la      t0, matvec_x
    vle32.v v1, (t0)
    vmv.v.x v0, x0
    la      t1, matvec_A
    li      t2, 0x4000

    vle32.v v2, (t1);  vmul.vv v3, v2, v1;  vredsum.vs v4, v3, v0;  vse32.v v4, (t2)
    addi    t1, t1, 16;  addi t2, t2, 16
    vle32.v v2, (t1);  vmul.vv v3, v2, v1;  vredsum.vs v4, v3, v0;  vse32.v v4, (t2)
    addi    t1, t1, 16;  addi t2, t2, 16
    vle32.v v2, (t1);  vmul.vv v3, v2, v1;  vredsum.vs v4, v3, v0;  vse32.v v4, (t2)
    addi    t1, t1, 16;  addi t2, t2, 16
    vle32.v v2, (t1);  vmul.vv v3, v2, v1;  vredsum.vs v4, v3, v0;  vse32.v v4, (t2)

    li      t2, 0x4000
    lw      t0, 0(t2);  li t1, 300; bne t0, t1, .Lmv_fail
    lw      t0, 16(t2); li t1, 70;  bne t0, t1, .Lmv_fail
    lw      t0, 32(t2); li t1, 110; bne t0, t1, .Lmv_fail
    lw      t0, 48(t2); li t1, 150; bne t0, t1, .Lmv_fail
    li      a0, 0;  j .Lmv_done
.Lmv_fail:
    li      a0, 1
.Lmv_done:
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# -----------------------------------------------------------------------
# run_matmul: C = A * B  (4x4, B column-major = A^T)
# -----------------------------------------------------------------------
run_matmul:
    addi    sp, sp, -16
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)

    la      t0, mm_A
    la      t1, mm_B
    li      t2, 0x4000
    vmv.v.x v0, x0
    li      a2, 0
    li      a3, 4

.Lmm_row:
    vle32.v v1, (t0)
    mv      a4, t1
    li      a5, 0
.Lmm_col:
    vle32.v v2, (a4)
    vmul.vv    v3, v1, v2
    vredsum.vs v4, v3, v0
    vmv.x.s    a1, v4
    sw      a1, 0(t2)
    addi    a4, a4, 16
    addi    t2, t2, 4
    addi    a5, a5, 1
    blt     a5, a3, .Lmm_col
    addi    t0, t0, 16
    addi    a2, a2, 1
    blt     a2, a3, .Lmm_row

    li      s0, 0x4000
    li      s1, 16
    la      s2, mm_expected
.Lmm_check:
    lw      t0, 0(s0)
    lw      t1, 0(s2)
    bne     t0, t1, .Lmm_fail
    addi    s0, s0, 4
    addi    s2, s2, 4
    addi    s1, s1, -1
    bnez    s1, .Lmm_check
    li      a0, 0;  j .Lmm_done
.Lmm_fail:
    li      a0, 1
.Lmm_done:
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    lw      s1, 8(sp)
    lw      s2, 12(sp)
    addi    sp, sp, 16
    ret

# -----------------------------------------------------------------------
# Messages
# -----------------------------------------------------------------------
msg_pass:   .asciz ": PASS\n"
msg_fail:   .asciz ": FAIL\n"
msg_saxpy:  .asciz "saxpy"
msg_dot:    .asciz "dot"
msg_matvec: .asciz "matvec"
msg_matmul: .asciz "matmul"
msg_done:   .asciz "--- done ---\n"

# -----------------------------------------------------------------------
# Test data
# -----------------------------------------------------------------------
.balign 4
saxpy_x:    .word 1, 2, 3, 4
saxpy_y:    .word 10, 20, 30, 40

.balign 4
dot_a:      .word 1, 2, 3, 4
dot_b:      .word 5, 6, 7, 8

.balign 4
matvec_x:   .word 1, 2, 3, 4
matvec_A:
    .word 10, 20, 30, 40
    .word  5,  6,  7,  8
    .word  9, 10, 11, 12
    .word 13, 14, 15, 16

.balign 4
mm_A:
    .word  1,  2,  3,  4
    .word  5,  6,  7,  8
    .word  9, 10, 11, 12
    .word 13, 14, 15, 16

mm_B:
    .word 1, 5,  9, 13
    .word 2, 6, 10, 14
    .word 3, 7, 11, 15
    .word 4, 8, 12, 16

mm_expected:
    .word  90, 100, 110, 120
    .word 202, 228, 254, 280
    .word 314, 356, 398, 440
    .word 426, 484, 542, 600

.include "uart_lib.s"
