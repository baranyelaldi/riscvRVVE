	.file	"sobel_scalar.c"
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
	lui	a5,%hi(sob_cols)
	lui	a3,%hi(sob_rowA)
	lui	a1,%hi(sob_rowB)
	lui	a2,%hi(sob_rowC)
	lw	a6,%lo(sob_cols)(a5)
	addi	a3,a3,%lo(sob_rowA)
	addi	a1,a1,%lo(sob_rowB)
	addi	a2,a2,%lo(sob_rowC)
	li	t5,16384
 #APP
# 24 "sobel_scalar.c" 1
	csrr zero, instret
	csrr t6, instret
	csrr t0, cycle
# 0 "" 2
 #NO_APP
	beq	a6,zero,.L2
	slli	a6,a6,2
	mv	a0,t5
	add	a6,a6,a3
.L3:
	lw	a5,8(a1)
	lw	a4,0(a1)
	lw	t4,8(a3)
	lw	t3,0(a3)
	lw	t1,8(a2)
	lw	a7,0(a2)
	slli	a5,a5,1
	slli	a4,a4,1
	add	a5,a5,t4
	add	a4,a4,t3
	add	a5,a5,t1
	add	a4,a4,a7
	sub	a5,a5,a4
	sw	a5,0(a0)
	addi	a3,a3,4
	addi	a1,a1,4
	addi	a2,a2,4
	addi	a0,a0,4
	bne	a6,a3,.L3
.L2:
 #APP
# 30 "sobel_scalar.c" 1
	csrr a3, cycle
	csrr a5, instret
# 0 "" 2
 #NO_APP
	li	a2,36864
	sub	a3,a3,t0
	sub	a5,a5,t6
	sw	a3,0(a2)
	addi	a5,a5,-3
	li	a4,36864
	sw	a5,16(a4)
	lw	a3,0(t5)
	li	a5,240
	bne	a3,a5,.L6
	lw	a5,4(t5)
	li	a4,80
	bne	a5,a4,.L7
	lw	a4,8(t5)
	bne	a4,a5,.L8
	lw	a3,12(t5)
	li	a5,1611489280
	li	a4,-280
	addi	a5,a5,13
	bne	a3,a4,.L15
.L5:
	li	a4,40960
	sw	a5,0(a4)
	li	a0,0
	ret
.L6:
	li	a5,0
.L4:
	li	a4,-1160773632
	or	a5,a5,a4
	j	.L5
.L7:
	li	a5,1
	j	.L4
.L8:
	li	a5,2
	j	.L4
.L15:
	li	a5,3
	j	.L4
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
