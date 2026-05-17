.section .text
.globl _start
_start:
    li      t3, 5                       # a = 5

    # Load x[] into v1
    la      t0, data_x
    vle32.v v1, (t0)

    # Load y[] into v2
    la      t1, data_y
    vle32.v v2, (t1)

    vmv.v.x v3, t3                      # v3 = {5, 5, 5, 5}

    # v4 = a * x   =  v3 * v1
    vmul.vv v4, v3, v1

    # v5 = a*x + y  =  v4 + v2
    vadd.vv v5, v4, v2
    # Store v5 to hardcoded address so we know where to look in TCM
    li      t2, 0x4000
    vse32.v v5, (t2)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_x:
    .word 1, 2, 3, 4

.balign 4
data_y:
    .word 10, 20, 30, 40
