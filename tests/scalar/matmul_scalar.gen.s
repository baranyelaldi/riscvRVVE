	.file	"matmul_scalar.c"
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
	addi	sp,sp,-16
	lui	a5,%hi(mm4_n)
	lui	t1,%hi(mm4_A)
	lui	t5,%hi(mm4_B)
	lw	t4,%lo(mm4_n)(a5)
	sw	s2,4(sp)
	sw	s3,0(sp)
	addi	t1,t1,%lo(mm4_A)
	addi	t5,t5,%lo(mm4_B)
	li	t6,16384
 #APP
# 28 "matmul_scalar.c" 1
	csrr zero, instret
	csrr s2, instret
	csrr s3, cycle
# 0 "" 2
 #NO_APP
	beq	t4,zero,.L2
	slli	t0,t4,2
	sw	s1,8(sp)
	neg	s1,t4
	sw	s0,12(sp)
	add	t3,t6,t0
	add	a0,t0,t1
	li	s0,0
	slli	s1,s1,3
.L3:
	sub	t2,t3,t0
	mv	a6,t2
	li	a7,0
.L5:
	slli	a3,a7,2
	add	a3,t5,a3
	mv	a5,t1
	li	a2,0
.L4:
	lw	a4,0(a5)
	lw	a1,0(a3)
	addi	a5,a5,4
	addi	a3,a3,4
	mul	a4,a4,a1
	add	a2,a2,a4
	bne	a5,a0,.L4
	sw	a2,0(a6)
	addi	a6,a6,4
	add	a7,a7,t4
	bne	a6,t3,.L5
	addi	s0,s0,1
	sub	t3,t2,s1
	add	t1,t1,t0
	add	a0,a0,t0
	bne	t4,s0,.L3
	lw	s0,12(sp)
	lw	s1,8(sp)
.L2:
 #APP
# 39 "matmul_scalar.c" 1
	csrr a5, cycle
	csrr a2, instret
# 0 "" 2
 #NO_APP
	li	a4,36864
	sub	a5,a5,s3
	sub	a2,a2,s2
	sw	a5,0(a4)
	li	a1,36864
	addi	a2,a2,-3
	lui	a3,%hi(.LANCHOR0)
	mv	a5,t6
	addi	a3,a3,%lo(.LANCHOR0)
	li	a4,0
	li	a0,16
	sw	a2,16(a1)
.L8:
	lw	a1,0(a5)
	lw	a2,0(a3)
	addi	a5,a5,4
	addi	a3,a3,4
	bne	a1,a2,.L18
	addi	a4,a4,1
	bne	a4,a0,.L8
	li	a4,1611489280
	addi	a4,a4,13
.L7:
	li	a5,40960
	sw	a4,0(a5)
	lw	s2,4(sp)
	lw	s3,0(sp)
	li	a0,0
	addi	sp,sp,16
	jr	ra
.L18:
	li	a5,-1160773632
	or	a4,a4,a5
	j	.L7
	.size	main, .-main
	.section	.rodata
	.align	2
	.set	.LANCHOR0,. + 0
	.type	expected, @object
	.size	expected, 64
expected:
	.word	30
	.word	70
	.word	110
	.word	150
	.word	70
	.word	174
	.word	278
	.word	382
	.word	110
	.word	278
	.word	446
	.word	614
	.word	150
	.word	382
	.word	614
	.word	846
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
