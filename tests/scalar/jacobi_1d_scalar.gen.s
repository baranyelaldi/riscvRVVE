	.file	"jacobi_1d_scalar.c"
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
	lui	a5,%hi(jac_n)
	lw	a1,%lo(jac_n)(a5)
	li	a3,16384
	sw	zero,0(a3)
	slli	a4,a1,2
	add	a4,a3,a4
	lui	a5,%hi(jac_A)
	sw	zero,-4(a4)
	addi	a5,a5,%lo(jac_A)
 #APP
# 26 "jacobi_1d_scalar.c" 1
	csrr zero, instret
	csrr a7, instret
	csrr t1, cycle
# 0 "" 2
 #NO_APP
	li	a4,1
	addi	a2,a1,-1
	bleu	a2,a4,.L2
	slli	a1,a1,2
	add	a1,a1,a5
	addi	a2,a3,4
	addi	a1,a1,-8
.L3:
	lw	a4,0(a5)
	lw	a6,4(a5)
	lw	a0,8(a5)
	addi	a5,a5,4
	add	a4,a4,a6
	add	a4,a4,a0
	sw	a4,0(a2)
	addi	a2,a2,4
	bne	a5,a1,.L3
.L2:
 #APP
# 29 "jacobi_1d_scalar.c" 1
	csrr a5, cycle
	csrr a2, instret
# 0 "" 2
 #NO_APP
	li	a4,36864
	sub	a5,a5,t1
	sub	a2,a2,a7
	sw	a5,0(a4)
	li	a1,36864
	addi	a2,a2,-3
	lui	a4,%hi(.LANCHOR0)
	mv	a5,a3
	addi	a4,a4,%lo(.LANCHOR0)
	li	a3,0
	li	a0,16
	sw	a2,16(a1)
.L6:
	lw	a1,0(a5)
	lw	a2,0(a4)
	addi	a5,a5,4
	addi	a4,a4,4
	bne	a1,a2,.L10
	addi	a3,a3,1
	bne	a3,a0,.L6
	li	a3,1611489280
	addi	a3,a3,13
.L5:
	li	a5,40960
	sw	a3,0(a5)
	li	a0,0
	ret
.L10:
	li	a5,-1160773632
	or	a3,a3,a5
	j	.L5
	.size	main, .-main
	.section	.rodata
	.align	2
	.set	.LANCHOR0,. + 0
	.type	expected, @object
	.size	expected, 64
expected:
	.word	0
	.word	60
	.word	90
	.word	120
	.word	150
	.word	180
	.word	210
	.word	240
	.word	270
	.word	300
	.word	330
	.word	360
	.word	390
	.word	420
	.word	450
	.word	0
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
