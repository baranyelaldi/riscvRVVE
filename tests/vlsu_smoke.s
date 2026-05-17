.section .text
.globl _start
_start:
    la      t0, data_x          # t0 = address of data_x
    vle32.v v1, (t0)            # v1 = mem[t0 .. t0+15]

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j 1b

.balign 4
data_x:
    .word 0xDEADBEEF
    .word 0xCAFEBABE
    .word 0x12345678
    .word 0x9ABCDEF0
