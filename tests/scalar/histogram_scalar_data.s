# Input for histogram_scalar.c — same 16 bytes as tests/histogram_selfcheck.s
# (values 0..3); length and bin count are data so they are runtime values.
.section .rodata
.balign 4
.global hist_data
.global hist_len
.global hist_bins
hist_data:
    .word 0x01010000, 0x02020101, 0x02020202, 0x03030303
hist_len:
    .word 16
hist_bins:
    .word 4
