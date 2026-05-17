.section .text
.globl _start
_start:
    # Load x[] into v1
    la      t0, data_x
    vle32.v v1, (t0)

    # Load y[] into v2
    la      t1, data_y
    vle32.v v2, (t1)

    # v3 = v1 + v2  (per-lane add)
    vadd.vv v3, v1, v2

    # Store v3 to z[]
    la      t2, data_z
    vse32.v v3, (t2)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_x:
    .word 1
    .word 2
    .word 3
    .word 4

.balign 4
data_y:
    .word 10
    .word 20
    .word 30
    .word 40

.balign 4
data_z:
    .word 0                     # space to store the result
    .word 0
    .word 0
    .word 0
