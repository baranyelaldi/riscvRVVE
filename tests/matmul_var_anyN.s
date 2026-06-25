# =============================================================
# matmul_var_anyN.s
# Variable-N matmul using incremental-pointer pattern (no MUL).
# Works for ANY N — no shift constants tied to a specific size.
#
# To test a different N:
#   1. Change `li a3, N` at top
#   2. Replace data_A / data_B blocks with N*N words each
#
# Both data_A (row-major) and data_B (column-major, = A^T) have
# the same byte pattern when B is logically A's transpose. So you
# can use the same data block for both — C = A x A^T (symmetric).
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
    li      a3, 4               # N = matrix size — CHANGE FOR DIFFERENT N

    # Precompute stride = N * 4 bytes (one row of A or one col of B).
    # Single shift — works for any N since we only need N*4, not N*N.
    slli    a7, a3, 2           # a7 = N * 4

    # -----------------------------------------------------------
    # Outer loop setup — A_row_ptr starts at A base
    # -----------------------------------------------------------
    mv      t0, a0              # t0 = A_row_ptr = &A[0][0]
    li      t6, 0               # i counter

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle           # s0 = start cycle

# ===============================================================
# OUTER ROW LOOP  i = 0..N-1
# ===============================================================
row_loop:
    # Reset B_col_ptr to B base at the start of each row
    mv      t1, a1              # t1 = B_col_ptr = &B[col 0]
    li      t2, 0               # j counter

# ===============================================================
# MIDDLE COL LOOP  j = 0..N-1
# Computes C[i][j] = dot(A_row_i, B_col_j)
# ===============================================================
col_loop:
    # -----------------------------------------------------------
    # Initialize vector accumulator v3 = {0, 0, 0, 0}
    # Set vl=4 (= VLMAX for e32/m1) so all lanes get zeroed
    # -----------------------------------------------------------
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v3, x0

    # -----------------------------------------------------------
    # Inner-loop setup — copy the row/col pointers, set remaining
    # We don't modify t0/t1 here so they stay valid for the next j
    # -----------------------------------------------------------
    mv      t4, t0              # inner a_ptr = current A row
    mv      t5, t1              # inner b_ptr = current B col
    mv      t3, a3              # remaining = N

# ===============================================================
# INNER LOOP — chunk through N elements of the dot product
# ===============================================================
inner_loop:
    vsetvli a4, t3, e32, m1     # a4 = vl = min(remaining, VLMAX)
    vle32.v v1, (t4)
    vle32.v v2, (t5)
    vmacc.vv v3, v1, v2         # v3[lane] += v1[lane] * v2[lane]

    slli    a5, a4, 2           # a5 = vl * 4 bytes
    add     t4, t4, a5
    add     t5, t5, a5
    sub     t3, t3, a4
    bnez    t3, inner_loop

    # -----------------------------------------------------------
    # Reduce v3 (4 partial sums) to a single scalar
    # Set vl=4 again — last inner iteration may have left vl<4
    # -----------------------------------------------------------
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v0, x0
    vredsum.vs v4, v3, v0
    vmv.x.s a6, v4

    # -----------------------------------------------------------
    # Store C[i][j] = a6, advance C pointer
    # -----------------------------------------------------------
    sw      a6, 0(a2)
    addi    a2, a2, 4

    # -----------------------------------------------------------
    # Advance B_col_ptr by stride (next column for next j)
    # -----------------------------------------------------------
    add     t1, t1, a7

    # j++; loop if j < N
    addi    t2, t2, 1
    blt     t2, a3, col_loop

    # -----------------------------------------------------------
    # End of row — advance A_row_ptr by stride (next row)
    # -----------------------------------------------------------
    add     t0, t0, a7

    # i++; loop if i < N
    addi    t6, t6, 1
    blt     t6, a3, row_loop

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot after kernel, store delta at 0x9000
    # -----------------------------------------------------------
    csrr    s1, cycle           # s1 = end cycle
    sub     s2, s1, s0          # s2 = elapsed cycles
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[0x9000] = cycle count  (= ram[9216])

    # -----------------------------------------------------------
    # Done
    # -----------------------------------------------------------
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# =============================================================
# Data — currently set for N=8 (matches the li a3, 8 above)
# A is row-major, B is column-major.
# B = A^T in logical sense, so data_B has the same byte pattern
# as data_A (each "column of B" is "row j of A" stored sequentially).
#
# For N=3 or N=4, replace BOTH data_A and data_B with the smaller
# block — see expected-results tables in the response.
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


