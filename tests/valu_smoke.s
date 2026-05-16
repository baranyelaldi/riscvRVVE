.section .text
.globl _start
_start:
li      t0, 5
li      t1, 3
vmv.v.x v1, t0          # v1 = {5,5,5,5}
vmv.v.x v2, t1          # v2 = {3,3,3,3}
nop
nop
vadd.vv v3, v1, v2      # v3 = {8,8,8,8}
vsub.vv v4, v1, v2      # v4 = {-2,-2,-2,-2} 0xfffffffe per lane
vmul.vv v5, v1, v2      # v5 = {15,15,15,15}

li      a0, 0
csrw    dscratch, a0
1: j 1b
