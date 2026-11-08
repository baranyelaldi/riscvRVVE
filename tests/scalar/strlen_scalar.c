// strlen_scalar.c — RV32IM scalar baseline for tests/strlen_selfcheck.s
//
// Same string, same result location (length at 0x4000, stored after the
// measured window like the vector version), same expected value (19).
#include "bench.h"

extern const char strlen_str[];

int main(void)
{
    const char *s = strlen_str;
    __asm__ volatile("" : "+r"(s));

    BENCH_START();
    uint32_t n = 0;
    while (s[n] != 0)
        n++;
    BENCH_STOP();

    *(volatile uint32_t *)0x4000 = n;
    RESULT_CHECK = (n == 19) ? CHECK_PASS : CHECK_FAIL(0);
    return 0;
}
