.section .text
.globl _start
_start:
    # Setup
    la      t0, data_a              # t0 = address of data_a
    li      t2, 0x4000              # t2 = destination

    # Iteration 0: load + store 
    vle32.v v1, (t0)
    vse32.v v1, (t2)

    # Iteration 1: increment, load+store
    addi    t0, t0, 16
    addi    t2, t2, 16
    vle32.v v2, (t0)
    vse32.v v2, (t2)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_a:
    .word 0xAA, 0xBB, 0xCC, 0xDD
    .word 0x11, 0x22, 0x33, 0x44
