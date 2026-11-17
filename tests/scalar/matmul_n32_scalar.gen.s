	.file	"matmul_n32_scalar.c"
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
	lui	t5,%hi(mm_A)
	lui	t1,%hi(mm_B)
	sw	s0,12(sp)
	sw	s1,8(sp)
	sw	s2,4(sp)
	sw	s3,0(sp)
	addi	t5,t5,%lo(mm_A)
	addi	t1,t1,%lo(mm_B)
	li	t6,32768
 #APP
# 24 "matmul_n32_scalar.c" 1
	csrr zero, instret
	csrr s1, instret
	csrr s2, cycle
# 0 "" 2
 #NO_APP
	li	s0,0
	addi	a0,t5,128
	li	t0,0
	li	t4,4096
	li	s3,1024
.L2:
	slli	t3,t0,2
	add	t3,t3,t5
	mv	t2,t6
	add	a7,t6,s0
	li	a6,0
.L4:
	add	a3,t1,a6
	mv	a5,t3
	li	a2,0
.L3:
	lw	a4,0(a5)
	lw	a1,0(a3)
	addi	a5,a5,4
	addi	a3,a3,4
	mul	a4,a4,a1
	add	a2,a2,a4
	bne	a5,a0,.L3
	sw	a2,0(a7)
	addi	a6,a6,128
	addi	a7,a7,4
	bne	a6,t4,.L4
	addi	t0,t0,32
	addi	s0,s0,128
	addi	a0,a5,128
	bne	t0,s3,.L2
 #APP
# 35 "matmul_n32_scalar.c" 1
	csrr a3, cycle
	csrr a5, instret
# 0 "" 2
 #NO_APP
	li	a2,36864
	sub	a3,a3,s2
	sub	a5,a5,s1
	addi	a5,a5,-3
	sw	a3,0(a2)
	li	a4,32
	sw	a5,16(a2)
	mv	a6,a4
	li	a1,0
.L6:
	addi	a5,a4,-32
	mv	a2,a4
	mv	a3,t2
	j	.L9
.L7:
	addi	a5,a5,1
	add	a2,a2,a4
	beq	a4,a5,.L16
.L9:
	lw	a0,0(a3)
	addi	a3,a3,4
	beq	a0,a2,.L7
	li	a4,-1160773632
	or	a5,a5,a4
.L8:
	lw	s0,12(sp)
	li	a4,40960
	sw	a5,0(a4)
	lw	s1,8(sp)
	lw	s2,4(sp)
	lw	s3,0(sp)
	li	a0,0
	addi	sp,sp,16
	jr	ra
.L16:
	addi	a1,a1,1
	addi	a4,a4,32
	addi	t2,t2,128
	bne	a1,a6,.L6
	li	a5,1611489280
	addi	a5,a5,13
	j	.L8
	.size	main, .-main
	.ident	"GCC: (g6afcc4f6d) 16.1.0"
	.section	.note.GNU-stack,"",@progbits
