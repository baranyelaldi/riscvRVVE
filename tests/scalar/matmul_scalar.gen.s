	.file	"matmul_scalar.c"
	.option nopic
	.attribute arch, "rv32i2p1_m2p0_zicsr2p0_zmmul1p0"
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
	lui	t3,%hi(mm4_A)
	lui	t5,%hi(mm4_B)
	lw	t4,%lo(mm4_n)(a5)
	sw	s0,12(sp)
	sw	s1,8(sp)
	addi	t3,t3,%lo(mm4_A)
	addi	t5,t5,%lo(mm4_B)
	li	t0,16384
 #APP
# 28 "matmul_scalar.c" 1
	csrr zero, instret
	csrr s0, instret
	csrr s1, cycle
# 0 "" 2
 #NO_APP
	beq	t4,zero,.L2
	slli	t6,t4,2
	add	a0,t6,t3
	add	t1,t0,t6
	li	t2,0
.L3:
	sub	a6,t1,t6
	li	a7,0
.L5:
	slli	a3,a7,2
	add	a3,t5,a3
	mv	a5,t3
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
	bne	a6,t1,.L5
	addi	t2,t2,1
	add	t1,t1,t6
	add	t3,t3,t6
	add	a0,a0,t6
	bne	t4,t2,.L3
.L2:
 #APP
# 39 "matmul_scalar.c" 1
	csrr a3, cycle
	csrr a5, instret
# 0 "" 2
 #NO_APP
	li	a2,36864
	sub	a3,a3,s1
	sub	a5,a5,s0
	addi	a5,a5,-3
	sw	a3,0(a2)
	lui	a3,%hi(.LANCHOR0)
	sw	a5,16(a2)
	addi	a3,a3,%lo(.LANCHOR0)
	mv	a5,t0
	li	a4,0
	li	a0,16
.L8:
	lw	a1,0(a5)
	lw	a2,0(a3)
	addi	a5,a5,4
	addi	a3,a3,4
	bne	a1,a2,.L17
	addi	a4,a4,1
	bne	a4,a0,.L8
	li	a4,1611489280
	addi	a4,a4,13
.L7:
	lw	s0,12(sp)
	li	a5,40960
	sw	a4,0(a5)
	lw	s1,8(sp)
	li	a0,0
	addi	sp,sp,16
	jr	ra
.L17:
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
	.ident	"GCC: (g6afcc4f6d) 16.1.0"
	.section	.note.GNU-stack,"",@progbits
