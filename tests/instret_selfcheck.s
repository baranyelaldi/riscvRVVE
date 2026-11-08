# =============================================================
# instret_selfcheck.s
# Self-checking validation of the instret CSR (0xC02).
#
# Measurement idiom (same as the benchmark wrapper):
#   csrr zero, instret   # drain: CSR ops are serialized, so every older
#                        # instruction has retired before the next CSR issues
#   csrr s3, instret     # exact start
#   ... K instructions ...
#   csrr zero, instret   # drain again
#   csrr s4, instret     # exact end
# delta = s4 - s3 = K + 2   (the start read itself + the end drain)
#
# Cases cover the ways a retire counter can go wrong: empty window,
# plain ALU, taken branches (squashed wrong-path fetches must not count),
# loads/stores, multi-cycle div/mul, vector ALU + V-LSU (incl. back-to-back
# vector loads), and a jump over an instruction that never executes.
#
# Result: ram[0xA000] = 0x600D600D (PASS) / 0xBAD00000 | case (FAIL)
# =============================================================

.macro IR_START
    csrr    zero, instret
    csrr    s3, instret
.endm

.macro IR_END expect, idx
    csrr    zero, instret
    csrr    s4, instret
    sub     t5, s4, s3
    li      t4, \expect
    li      t3, \idx
    bne     t5, t4, check_fail
.endm

.text
.global _start
_start:
    # Case 0: empty window -> K=0
    IR_START
    IR_END  2, 0

    # Case 1: 5 ALU ops -> K=5
    IR_START
    addi    t0, zero, 1
    addi    t0, t0, 1
    addi    t0, t0, 1
    addi    t0, t0, 1
    addi    t0, t0, 1
    IR_END  7, 1

    # Case 2: loop, 4 iterations, 3 taken branches -> K = 1 + 4*2 = 9
    IR_START
    addi    t0, zero, 4
1:  addi    t0, t0, -1
    bnez    t0, 1b
    IR_END  11, 2

    # Case 3: store + load -> K=3
    IR_START
    lui     t1, 0x4
    sw      t1, 0(t1)
    lw      t2, 0(t1)
    IR_END  5, 3

    # Case 4: multi-cycle div + mul -> K=4
    IR_START
    addi    t1, zero, 100
    addi    t2, zero, 7
    div     t6, t1, t2
    mul     t6, t6, t2
    IR_END  6, 4

    # Case 5: vector config + V-LSU load + V-ALU + V-LSU store -> K=6
    IR_START
    addi    a5, zero, 4
    vsetvli zero, a5, e32, m1
    lui     t1, 0x4
    vle32.v v1, (t1)
    vadd.vv v2, v1, v1
    vse32.v v2, (t1)
    IR_END  8, 5

    # Case 6: back-to-back vector loads + vmacc -> K=3
    IR_START
    vle32.v v1, (t1)
    vle32.v v2, (t1)
    vmacc.vv v3, v1, v2
    IR_END  5, 6

    # Case 7: jump over an instruction -> K=1 (the skipped addi never retires)
    IR_START
    j       2f
    addi    t0, zero, 99
2:
    IR_END  3, 7

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
