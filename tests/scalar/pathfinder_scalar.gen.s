	.file	"pathfinder_scalar.c"
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
	lui	a5,%hi(pf_cols)
	lui	a4,%hi(pf_src)
	lui	a3,%hi(pf_grid)
	lw	a1,%lo(pf_cols)(a5)
	addi	a4,a4,%lo(pf_src)
	addi	a3,a3,%lo(pf_grid)
	li	a6,16384
 #APP
# 25 "pathfinder_scalar.c" 1
	csrr zero, instret
	csrr a7, instret
	csrr t1, cycle
# 0 "" 2
 #NO_APP
	beq	a1,zero,.L2
	slli	a1,a1,2
	mv	a2,a6
	add	a1,a1,a4
.L5:
	lw	a5,4(a4)
	lw	a0,8(a4)
	bleu	a5,a0,.L3
	mv	a5,a0
.L3:
	lw	a0,0(a4)
	addi	a4,a4,4
	bleu	a5,a0,.L4
	mv	a5,a0
.L4:
	lw	a0,0(a3)
	addi	a2,a2,4
	addi	a3,a3,4
	add	a5,a5,a0
	sw	a5,-4(a2)
	bne	a1,a4,.L5
.L2:
 #APP
# 28 "pathfinder_scalar.c" 1
	csrr a3, cycle
	csrr a5, instret
# 0 "" 2
 #NO_APP
	li	a2,36864
	sub	a3,a3,t1
	sub	a5,a5,a7
	sw	a3,0(a2)
	addi	a5,a5,-3
	li	a4,36864
	sw	a5,16(a4)
	lw	a5,0(a6)
	li	a3,6
	bne	a5,a3,.L8
	lw	a4,4(a6)
	li	a3,7
	bne	a4,a3,.L9
	lw	a3,8(a6)
	bne	a3,a5,.L10
	lw	a3,12(a6)
	li	a5,1611489280
	addi	a5,a5,13
	bne	a3,a4,.L17
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
.L17:
	li	a5,3
	j	.L6
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
