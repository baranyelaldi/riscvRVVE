# =============================================================
# jacobi_1d_selfcheck.s — self-checking copy of jacobi_1d.s
#   ram[0x9000] = kernel cycles ; ram[0xA000] = PASS/FAIL
# Expected B[0..15]: B[0]=B[15]=0; B[i]=30*(i+1) for i=1..14
#   {0, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360, 390, 420, 450, 0}
# =============================================================
.text
.global _start
_start:
    la      a0, data_A
    li      a1, 0x4000
    li      a2, 16

    sw      zero, 0(a1)         # B[0] = 0
    addi    t5, a2, -1
    slli    t5, t5, 2
    add     t5, a1, t5
    sw      zero, 0(t5)         # B[N-1] = 0

    mv      t0, a0
    addi    t1, a0, 4
    addi    t2, a0, 8
    addi    t3, a1, 4
    addi    t4, a2, -2

    csrr    s0, cycle
chunk_loop:
    vsetvli a3, t4, e32, m1
    vle32.v v1, (t0)
    vle32.v v2, (t1)
    vle32.v v3, (t2)
    vadd.vv v4, v1, v2
    vadd.vv v4, v4, v3
    vse32.v v4, (t3)
    slli    a4, a3, 2
    add     t0, t0, a4
    add     t1, t1, a4
    add     t2, t2, a4
    add     t3, t3, a4
    sub     t4, t4, a3
    bnez    t4, chunk_loop

    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)

    # ===== SELF-CHECK: all 16 output cells =====
    la      t0, expected
    li      t1, 0x4000
    li      t2, 16
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
data_A:
    .word  10,  20,  30,  40
    .word  50,  60,  70,  80
    .word  90, 100, 110, 120
    .word 130, 140, 150, 160

.balign 4
expected:
    .word 0,     0x3C,  0x5A,  0x78    # B[0..3]  = 0, 60, 90, 120
    .word 0x96,  0xB4,  0xD2,  0xF0    # B[4..7]  = 150, 180, 210, 240
    .word 0x10E, 0x12C, 0x14A, 0x168   # B[8..11] = 270, 300, 330, 360
    .word 0x186, 0x1A4, 0x1C2, 0       # B[12..15]= 390, 420, 450, 0
