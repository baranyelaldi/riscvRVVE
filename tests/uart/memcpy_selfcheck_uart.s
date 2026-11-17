# =============================================================
# memcpy_selfcheck_uart.s
# UART (FPGA) version of memcpy_selfcheck.s (20-byte vector memcpy, e8).
#
# Kernel, cycle/instret measurement and self-check are identical to
# memcpy_selfcheck.s, except the source buffer lives at 0x6000 instead of
# 0x2000: 0x2000 is where the program code starts, so writing the source
# pattern there overwrites the first instructions. That is harmless for one
# run, but on the FPGA the BRAM is not reloaded by the CPU reset button, so a
# second run would execute the data words. TCM latency is the same at every
# address, so the measured cycles are unaffected.
#
# Results are still written to the same RAM words:
#   ram[0x9000] = kernel cycle count
#   ram[0x9010] = kernel retired-instruction count
#   ram[0xA000] = 0x600D600D -> PASS / 0xBAD00000 | idx -> FAIL at idx
# Checks the 5 copied words + the untouched sentinel word after them
# (proves the copy is correct AND did not overrun 20 bytes).
#
# After that the results are reported over the UART (0x8000_0000):
#   memcpy_selfcheck
#   PASS                      (or: FAIL at 0000000X)
#   CYCLES  XXXXXXXX          (hex)
#   INSTRET XXXXXXXX          (hex)
#
# Simulation: `csrw dscratch, zero` ends the Verilator run BEFORE the UART
# part (the tb does not answer peripheral writes), so the testbench still
# prints [SELF-CHECK] / [CYCLES] / [INSTRET] as usual.
# FPGA: the dscratch write is a no-op, so execution continues to the UART part.
#
# Build (from tests/):  make uart/memcpy_selfcheck_uart.elf
#                       make mem uart/memcpy_selfcheck_uart.elf
# =============================================================

.text
.global _start
_start:
    # source pattern at 0x6000
    li      t0, 0x6000
    li      t1, 0x13121110; sw t1, 0(t0)
    li      t1, 0x17161514; sw t1, 4(t0)
    li      t1, 0x1B1A1918; sw t1, 8(t0)
    li      t1, 0x1F1E1D1C; sw t1, 12(t0)
    li      t1, 0x23222120; sw t1, 16(t0)

    # pre-seed dst at 0x4000 with 0xFF sentinel
    li      t2, 0x4000
    li      t1, 0xFFFFFFFF
    sw      t1, 0(t2)
    sw      t1, 4(t2)
    sw      t1, 8(t2)
    sw      t1, 12(t2)
    sw      t1, 16(t2)
    sw      t1, 20(t2)

    li      a0, 0x6000          # src
    li      a1, 0x4000          # dst
    li      a2, 20              # n = 20 bytes

    csrr    zero, instret       # drain: older instructions retire before the next CSR issues
    csrr    s3, instret         # exact start of the instret window
    csrr    s0, cycle
memcpy_loop:
    vsetvli a3, a2, e8, m1
    vle8.v  v1, (a0)
    vse8.v  v1, (a1)
    add     a0, a0, a3
    add     a1, a1, a3
    sub     a2, a2, a3
    bnez    a2, memcpy_loop

    csrr    s1, cycle
    csrr    s4, instret         # exact end (follows a CSR op -> kernel fully retired)
    sub     s2, s1, s0
    li      t0, 0x9000
    sw      s2, 0(t0)
    sub     s5, s4, s3          # retired instructions in the window
    addi    s5, s5, -3          # minus wrapper: instret start read + 2x cycle read
    sw      s5, 16(t0)          # ram[0x9010] = kernel instret (tb prints [INSTRET])

    # ===== SELF-CHECK: 5 copied words + 1 untouched sentinel =====
    la      t0, expected
    li      t1, 0x4000
    li      t2, 6
    li      t3, 0
check_loop:
    lw      t4, 0(t1)
    lw      t5, 0(t0)
    bne     t4, t5, check_fail
    addi    t0, t0, 4
    addi    t1, t1, 4
    addi    t3, t3, 1
    blt     t3, t2, check_loop
check_pass:
    li      s6, 0x600D600D
    j       check_report
check_fail:
    li      t5, 0xBAD00000
    or      s6, t5, t3
check_report:
    li      t0, 0xA000
    sw      s6, 0(t0)

    # -----------------------------------------------------------
    # End of simulation (no-op on FPGA)
    # -----------------------------------------------------------
    csrw    dscratch, zero

    # ===========================================================
    # UART REPORT (FPGA only). uart_lib clobbers t0-t4 and a0;
    # results live in s2 (cycles), s5 (instret), s6 (check word).
    # ===========================================================
    la      a0, msg_name
    call    uart_print_str

    li      t0, 0x600D600D
    bne     s6, t0, report_fail
    la      a0, msg_pass
    call    uart_print_str
    j       report_counts
report_fail:
    la      a0, msg_fail
    call    uart_print_str
    li      t0, 0xFFFF
    and     a0, s6, t0          # failing check index
    call    uart_print_hex

report_counts:
    la      a0, msg_cycles
    call    uart_print_str
    mv      a0, s2
    call    uart_print_hex

    la      a0, msg_instret
    call    uart_print_str
    mv      a0, s5
    call    uart_print_hex

    # -----------------------------------------------------------
    # Done
    # -----------------------------------------------------------
1:  j       1b

msg_name:    .asciz "memcpy_selfcheck\n"
msg_pass:    .asciz "PASS\n"
msg_fail:    .asciz "FAIL at "
msg_cycles:  .asciz "CYCLES  "
msg_instret: .asciz "INSTRET "

.balign 4
expected:
    .word 0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120
    .word 0xFFFFFFFF                # sentinel: bytes 20..23 untouched

.balign 4
.include "uart_lib.s"
