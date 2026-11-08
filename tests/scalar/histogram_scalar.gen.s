	.file	"histogram_scalar.c"
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
	lui	a5,%hi(hist_len)
	lw	a1,%lo(hist_len)(a5)
	lui	a4,%hi(hist_data)
	lui	a5,%hi(hist_bins)
	lw	a3,%lo(hist_bins)(a5)
	addi	a4,a4,%lo(hist_data)
	li	a2,16384
 #APP
# 23 "histogram_scalar.c" 1
	csrr zero, instret
	csrr a0, instret
	csrr a6, cycle
# 0 "" 2
 #NO_APP
	beq	a3,zero,.L2
	slli	a3,a3,2
	mv	a5,a2
	add	a3,a3,a2
.L3:
	sw	zero,0(a5)
	addi	a5,a5,4
	bne	a5,a3,.L3
.L2:
	beq	a1,zero,.L4
	add	a1,a1,a4
.L5:
	lbu	a5,0(a4)
	addi	a4,a4,1
	slli	a5,a5,2
	add	a5,a2,a5
	lw	a3,0(a5)
	addi	a3,a3,1
	sw	a3,0(a5)
	bne	a1,a4,.L5
.L4:
 #APP
# 28 "histogram_scalar.c" 1
	csrr a3, cycle
	csrr a5, instret
# 0 "" 2
 #NO_APP
	li	a1,36864
	sub	a3,a3,a6
	sub	a5,a5,a0
	sw	a3,0(a1)
	addi	a5,a5,-3
	li	a4,36864
	sw	a5,16(a4)
	lw	a3,0(a2)
	li	a5,2
	bne	a3,a5,.L8
	lw	a4,4(a2)
	li	a5,4
	bne	a4,a5,.L9
	lw	a3,8(a2)
	li	a5,6
	bne	a3,a5,.L10
	lw	a3,12(a2)
	li	a5,1611489280
	addi	a5,a5,13
	bne	a3,a4,.L21
.L7:
	li	a4,40960
	sw	a5,0(a4)
	li	a0,0
	ret
.L8:
	li	a5,0
.L6:
	li	a4,-1160773632
	or	a5,a5,a4
	j	.L7
.L9:
	li	a5,1
	j	.L6
.L10:
	li	a5,2
	j	.L6
.L21:
	li	a5,3
	j	.L6
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
