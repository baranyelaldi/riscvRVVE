.section .text
.globl _start
_start:
    nop
    nop
    vadd.vv v4, v2, v0
    nop
    nop
    li a0, 0
    csrw dscratch, a0
1:  j 1b

