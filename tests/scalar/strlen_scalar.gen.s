	.file	"strlen_scalar.c"
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
	lui	a3,%hi(strlen_str)
	addi	a3,a3,%lo(strlen_str)
 #APP
# 14 "strlen_scalar.c" 1
	csrr zero, instret
	csrr a1, instret
	csrr a0, cycle
# 0 "" 2
 #NO_APP
	lbu	a5,0(a3)
	beq	a5,zero,.L5
	li	a5,0
.L3:
	addi	a5,a5,1
	add	a4,a3,a5
	lbu	a4,0(a4)
	bne	a4,zero,.L3
.L2:
 #APP
# 18 "strlen_scalar.c" 1
	csrr a2, cycle
	csrr a4, instret
# 0 "" 2
 #NO_APP
	sub	a2,a2,a0
	sub	a4,a4,a1
	li	a1,36864
	sw	a2,0(a1)
	addi	a4,a4,-3
	li	a3,36864
	sw	a4,16(a3)
	li	a4,16384
	sw	a5,0(a4)
	li	a2,19
	li	a4,-1160773632
	bne	a5,a2,.L4
	li	a4,1611489280
	addi	a4,a4,13
.L4:
	li	a5,40960
	sw	a4,0(a5)
	li	a0,0
	ret
.L5:
	li	a5,0
	j	.L2
	.size	main, .-main
	.ident	"GCC: (13.2.0-11ubuntu1+12) 13.2.0"
