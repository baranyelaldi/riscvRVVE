.section .text
.globl _start
_start:
    # Load x[] into v1 (reused across all 4 rows)
    la      t0, data_x
    vle32.v v1, (t0)

    # Zero accumulator for vredsum
    vmv.v.x v0, x0                  # v0 = {0, 0, 0, 0}

    # Pointers — t1 walks through A's rows, t2 walks through result slots
    la      t1, data_A
    li      t2, 0x4000

    # ---- Row 0: y[0] = A[0] · x ----
    vle32.v v2, (t1)                # v2 = A[0][*]
    vmul.vv v3, v2, v1              # v3[i] = A[0][i] * x[i]
    vredsum.vs v4, v3, v0           # v4[0] = sum of v3
    vse32.v v4, (t2)                # store (only v4[0] is meaningful)

    # ---- Row 1 ----
    addi    t1, t1, 16              # next row of A (4 elements × 4 bytes)
    addi    t2, t2, 16              # next result slot
    vle32.v v2, (t1)
    vmul.vv v3, v2, v1
    vredsum.vs v4, v3, v0
    vse32.v v4, (t2)

    # ---- Row 2 ----
    addi    t1, t1, 16
    addi    t2, t2, 16
    vle32.v v2, (t1)
    vmul.vv v3, v2, v1
    vredsum.vs v4, v3, v0
    vse32.v v4, (t2)

    # ---- Row 3 ----
    addi    t1, t1, 16
    addi    t2, t2, 16
    vle32.v v2, (t1)
    vmul.vv v3, v2, v1
    vredsum.vs v4, v3, v0
    vse32.v v4, (t2)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_x:
    .word 1, 2, 3, 4

.balign 4
data_A:
    .word 10,  20,  30,  40             # row 0
    .word 5,  6,  7,  8             # row 1
    .word 9,  10, 11, 12            # row 2
    .word 13, 14, 15, 16            # row 3
