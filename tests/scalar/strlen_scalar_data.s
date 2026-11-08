# Input for strlen_scalar.c — same string as tests/strlen_selfcheck.s.
# In assembly so the compiler cannot see the string and fold the length.
.section .rodata
.balign 4
.global strlen_str
strlen_str:
    .asciz "Hello RVVE vectors!"
    .zero  16
