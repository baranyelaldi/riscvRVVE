	.file	"memcpy_scalar.c"
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
	li	a4,16384
	li	a5,-1
	sw	a5,0(a4)
	sw	a5,4(a4)
	sw	a5,8(a4)
	sw	a5,12(a4)
	sw	a5,16(a4)
	sw	a5,20(a4)
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
	bne	a3,a5,.L3
.L2:
 #APP
# 33 "memcpy_scalar.c" 1
	csrr a5, cycle
	csrr a4, instret
# 0 "" 2
 #NO_APP
	li	a3,36864
	sub	a5,a5,a0
	sub	a4,a4,a1
	sw	a5,0(a3)
	lui	a5,%hi(.LANCHOR0)
	addi	a4,a4,-3
	addi	a5,a5,%lo(.LANCHOR0)
	li	a1,16384
	sw	a4,16(a3)
	sub	a1,a1,a5
	li	a4,0
	li	a0,6
.L6:
	add	a3,a1,a5
	lw	a2,0(a3)
	lw	a3,0(a5)
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
	.ident	"GCC: (g6afcc4f6d) 16.1.0"
	.section	.note.GNU-stack,"",@progbits
