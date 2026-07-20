# =============================================================
# matmul_selfcheck.s
# Self-checking copy of matmul_var_anyN.s (N=4, C = A x A^T).
#
# Same kernel as matmul_var_anyN.s, PLUS an in-program self-check
# (riscv-tests style): after the kernel, compare the computed C
# matrix against embedded hand-computed expected values and emit a
# single PASS/FAIL result.
#
# Results:
#   ram[0x9000] = kernel cycle count  (measured BEFORE the self-check,
#                 so the self-check adds zero cycles to the metric)
#   ram[0xA000] = 0x600D600D            -> PASS (all 16 cells matched)
#               = 0xBAD00000 | idx      -> FAIL at check index `idx`
# Dedicated result address 0xA000 + magic values so the testbench's
# end-of-sim reporter never misfires on tests that don't self-check.
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup
    # -----------------------------------------------------------
    la      a0, data_A          # A base (row-major)
    la      a1, data_B          # B base (column-major)
    li      a2, 0x4000          # C base in TCM (row-major output)
    li      a3, 4               # N = matrix size

    slli    a7, a3, 2           # a7 = N * 4 (stride)

    mv      t0, a0              # t0 = A_row_ptr
    li      t6, 0               # i counter

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle

# ===============================================================
# OUTER ROW LOOP  i = 0..N-1
# ===============================================================
row_loop:
    mv      t1, a1              # B_col_ptr = B base (reset each row)
    li      t2, 0               # j counter

col_loop:
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v3, x0

    mv      t4, t0              # inner A ptr
    mv      t5, t1              # inner B ptr
    mv      t3, a3              # remaining = N

inner_loop:
    vsetvli a4, t3, e32, m1
    vle32.v v1, (t4)
    vle32.v v2, (t5)
    vmacc.vv v3, v1, v2

    slli    a5, a4, 2
    add     t4, t4, a5
    add     t5, t5, a5
    sub     t3, t3, a4
    bnez    t3, inner_loop

    # reduce v3 to scalar
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v0, x0
    vredsum.vs v4, v3, v0
    vmv.x.s a6, v4

    sw      a6, 0(a2)           # store C[i][j]
    addi    a2, a2, 4

    add     t1, t1, a7          # next B column
    addi    t2, t2, 1
    blt     t2, a3, col_loop

    add     t0, t0, a7          # next A row
    addi    t6, t6, 1
    blt     t6, a3, row_loop

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot AFTER kernel (metric ends here)
    # -----------------------------------------------------------
    csrr    s1, cycle
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[0x9000] = kernel cycles (self-check excluded)

    # ===========================================================
    # SELF-CHECK — runs AFTER the cycle snapshot, so it does NOT
    # affect ram[0x9000]. Compares C (0x4000..) vs `expected`.
    # ===========================================================
    la      t0, expected        # expected[] pointer
    li      t1, 0x4000          # computed C pointer
    li      t2, 16              # N*N words to check
    li      t3, 0               # check index

check_loop:
    lw      t4, 0(t1)           # computed[i]
    lw      t5, 0(t0)           # expected[i]
    bne     t4, t5, check_fail  # mismatch -> fail
    addi    t0, t0, 4
    addi    t1, t1, 4
    addi    t3, t3, 1
    blt     t3, t2, check_loop

check_pass:
    li      t6, 0x600D600D      # PASS magic
    j       check_report
check_fail:
    li      t5, 0xBAD00000
    or      t6, t5, t3          # FAIL: 0xBAD00000 | failing_index

check_report:
    li      t0, 0xA000
    sw      t6, 0(t0)           # ram[0xA000] = PASS/FAIL result

    # -----------------------------------------------------------
    # Done
    # -----------------------------------------------------------
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# =============================================================
# Data — N=4, A = 1..16 row-major; B = A^T (same byte pattern)
# =============================================================
.balign 4
data_A:
    .word  1,  2,  3,  4
    .word  5,  6,  7,  8
    .word  9, 10, 11, 12
    .word 13, 14, 15, 16

.balign 4
data_B:
    .word  1,  2,  3,  4
    .word  5,  6,  7,  8
    .word  9, 10, 11, 12
    .word 13, 14, 15, 16

# =============================================================
# Expected C = A x A^T (hand-computed, verified in benchmarks.md).
# C[i][j] = sum_k A[i][k]*A[j][k]. Symmetric.
# =============================================================
.balign 4
expected:
    .word 0x1E,  0x46,  0x6E,  0x96     # C[0][*] = 30, 70, 110, 150
    .word 0x46,  0xAE,  0x116, 0x17E    # C[1][*] = 70, 174, 278, 382
    .word 0x6E,  0x116, 0x1BE, 0x266    # C[2][*] = 110, 278, 446, 614
    .word 0x96,  0x17E, 0x266, 0x34E    # C[3][*] = 150, 382, 614, 846
