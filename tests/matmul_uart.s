.text
.global _start
_start:
    la      t0, data_A
    la      t1, data_B
    li      t2, 0x4000              # C base in TCM

    vmv.v.x v0, x0                  # v0 = {0,0,0,0} accumulator zero

    li      a2, 0
    li      a3, 4

row_loop:
    vle32.v v1, (t0)
    mv      a4, t1
    li      a5, 0

col_loop:
    vle32.v v2, (a4)
    vmul.vv    v3, v1, v2
    vredsum.vs v4, v3, v0
    vmv.x.s    a1, v4
    sw      a1, 0(t2)

    addi    a4, a4, 16
    addi    t2, t2, 4
    addi    a5, a5, 1
    blt     a5, a3, col_loop

    addi    t0, t0, 16
    addi    a2, a2, 1
    blt     a2, a3, row_loop

    # Print all 16 results over UART as 8 hex chars + newline each.
    # Expected output:
    #   0000005A  (90)    0000006E  (110)
    #   00000064  (100)   00000078  (120)
    #   000000CA  (202)   000000FE  (254)
    #   000000E4  (228)   00000118  (280)
    #   0000013A  (314)   0000018E  (398)
    #   00000164  (356)   000001B8  (440)
    #   000001AA  (426)   0000021E  (542)
    #   000001E4  (484)   00000258  (600)
    li      s0, 0x4000              # pointer into result array
    li      s1, 16                  # 16 elements

print_loop:
    lw      a0, 0(s0)               # load one result word
    call    print_hex               # print as 8 hex chars + newline
    addi    s0, s0, 4
    addi    s1, s1, -1
    bnez    s1, print_loop

1:  j       1b                      # halt

# -----------------------------------------------------------------------
# print_hex: send a0 to UART as 8 uppercase hex chars followed by '\n'
# Clobbers: t1-t5
# -----------------------------------------------------------------------
print_hex:
    li      t1, 0x80000000          # UART TX address
    li      t2, 28                  # start with the top nibble (bits 31:28)
    li      t3, 8                   # 8 nibbles total
nibble_loop:
    srl     t4, a0, t2              # shift nibble into bits [3:0]
    andi    t4, t4, 0xF
    li      t5, 10
    blt     t4, t5, nibble_is_digit
    addi    t4, t4, 55              # 'A' - 10 = 55  →  A-F
    j       nibble_send
nibble_is_digit:
    addi    t4, t4, 48              # '0' = 48  →  0-9
nibble_send:
    sw      t4, 0(t1)               # one byte to UART
    addi    t2, t2, -4
    addi    t3, t3, -1
    bnez    t3, nibble_loop
    li      t4, 10                  # '\n'
    sw      t4, 0(t1)
    ret

.balign 4
data_A:                             # row-major 4x4
    .word 1, 2, 3, 4
    .word 5, 6, 7, 8
    .word 9, 10, 11, 12
    .word 13, 14, 15, 16

.balign 4
data_B:                             # column-major 4x4 (= A^T)
    .word 1, 5,  9, 13
    .word 2, 6, 10, 14
    .word 3, 7, 11, 15
    .word 4, 8, 12, 16
