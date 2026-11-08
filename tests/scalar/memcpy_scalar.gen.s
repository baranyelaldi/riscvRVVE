	.file	"memcpy_scalar.c"
	.option nopic
	.attribute arch, "rv32i2p1_m2p0_zicsr2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	li	a5,-1
	li	a4,16384
	sw	a5,0(a4)
	li	a7,16384
	sw	a5,4(a7)
	li	a6,16384
	sw	a5,8(a6)
	li	a0,16384
	sw	a5,12(a0)
	li	a1,16384
	sw	a5,16(a1)
	li	a2,16384
	sw	a5,20(a2)
	lui	a5,%hi(memcpy_len)
	lw	a3,%lo(memcpy_len)(a5)
	lui	a5,%hi(memcpy_src)
	addi	a5,a5,%lo(memcpy_src)
 #APP
# 30 "memcpy_scalar.c" 1
	csrr zero, instret
	csrr a1, instret
	csrr a0, cycle
# 0 "" 2
 #NO_APP
	beq	a3,zero,.L2
	add	a3,a3,a5
.L3:
	lbu	a2,0(a5)
	addi	a5,a5,1
	addi	a4,a4,1
	sb	a2,-1(a4)
	bne	a5,a3,.L3
.L2:
 #APP
# 33 "memcpy_scalar.c" 1
	csrr a5, cycle
	csrr a3, instret
# 0 "" 2
 #NO_APP
	li	a4,36864
	sub	a5,a5,a0
	sw	a5,0(a4)
	sub	a3,a3,a1
	lui	a5,%hi(.LANCHOR0)
	li	a2,36864
	addi	a3,a3,-3
	addi	a5,a5,%lo(.LANCHOR0)
	li	a1,16384
	li	a4,0
	sub	a1,a1,a5
	li	a0,6
	sw	a3,16(a2)
.L6:
	add	a2,a1,a5
	lw	a3,0(a5)
	lw	a2,0(a2)
	addi	a5,a5,4
	bne	a2,a3,.L13
	addi	a4,a4,1
	bne	a4,a0,.L6
	li	a4,1611489280
	addi	a4,a4,13
.L5:
	li	a5,40960
	sw	a4,0(a5)
	li	a0,0
	ret
.L13:
	li	a5,-1160773632
	or	a4,a4,a5
	j	.L5
	.size	main, .-main
	.section	.rodata
	.align	2
	.set	.LANCHOR0,. + 0
	.type	expected, @object
	.size	expected, 24
expected:
	.word	319951120
	.word	387323156
	.word	454695192
	.word	522067228
	.word	589439264
	.word	-1
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
