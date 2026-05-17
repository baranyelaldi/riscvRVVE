.section .text
.globl _start
_start:
    # Load a[] into v1
    la      t0, data_a
    vle32.v v1, (t0)

    # Load b[] into v2
    la      t1, data_b
    vle32.v v2, (t1)

    # v3[i] = a[i] * b[i]   (element-wise products)
    vmul.vv v3, v1, v2

    # v4 = {0, 0, 0, 0}     (accumulator init for reduction)
    vmv.v.x v4, x0

    # v5[0] = v4[0] + Σ v3[i] = 0 + (a · b)
    # Assembly order: vredsum.vs vd, vs2, vs1
    vredsum.vs v5, v3, v4

    # Store result (just v5[0] matters; v5[1..3] are zero tail)
    li      t2, 0x4000
    vse32.v v5, (t2)

    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_a:
    .word 1, 2, 3, 4

.balign 4
data_b:
    .word 5, 6, 7, 8
