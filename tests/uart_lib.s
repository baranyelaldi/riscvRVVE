# UART helper routines for FPGA tests.
# Usage: add   .include "uart_lib.s"   at the end of your test file.
#
# Functions (all clobber only t-registers):
#   uart_putc        a0 = character to send
#   uart_print_hex   a0 = 32-bit value → 8 uppercase hex chars + newline
#   uart_print_str   a0 = address of null-terminated string
#   uart_newline     sends '\n'

.equ UART_TX, 0x80000000

# -----------------------------------------------------------------------
uart_putc:
    li      t0, UART_TX
    sw      a0, 0(t0)
    ret

# -----------------------------------------------------------------------
uart_print_hex:
    li      t0, UART_TX
    li      t1, 28              # start with bits [31:28]
    li      t2, 8               # 8 nibbles
.Lhex_loop:
    srl     t3, a0, t1
    andi    t3, t3, 0xF
    li      t4, 10
    blt     t3, t4, .Lhex_digit
    addi    t3, t3, 55          # 'A' - 10
    j       .Lhex_send
.Lhex_digit:
    addi    t3, t3, 48          # '0'
.Lhex_send:
    sw      t3, 0(t0)
    addi    t1, t1, -4
    addi    t2, t2, -1
    bnez    t2, .Lhex_loop
    li      t3, 10              # newline
    sw      t3, 0(t0)
    ret

# -----------------------------------------------------------------------
uart_print_str:
    li      t0, UART_TX
.Lstr_loop:
    lb      t1, 0(a0)
    beqz    t1, .Lstr_done
    sw      t1, 0(t0)
    addi    a0, a0, 1
    j       .Lstr_loop
.Lstr_done:
    ret

# -----------------------------------------------------------------------
uart_newline:
    li      t0, UART_TX
    li      t1, 10
    sw      t1, 0(t0)
    ret
