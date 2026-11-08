// memcpy_scalar.c — RV32IM scalar baseline for tests/memcpy_selfcheck.s
//
// Same input (20 bytes), same destination (0x4000 pre-seeded with 0xFF),
// same self-check: the 5 copied words + the untouched sentinel word after
// them. Byte loop = generic memcpy semantics (any alignment, runtime n),
// matching what the vector version guarantees.
#include "bench.h"

extern const uint8_t  memcpy_src[];
extern const uint32_t memcpy_len;

static const uint32_t expected[6] = {
    0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120,
    0xFFFFFFFF  // sentinel: bytes 20..23 must stay untouched
};

int main(void)
{
    volatile uint32_t *dst32 = (volatile uint32_t *)0x4000;
    for (int i = 0; i < 6; i++)
        dst32[i] = 0xFFFFFFFF;

    const uint8_t *src = memcpy_src;
    uint8_t       *dst = (uint8_t *)0x4000;
    uint32_t       n   = *(volatile const uint32_t *)&memcpy_len;
    // Materialise the arguments in registers before the window opens
    // (the vector version sets a0/a1/a2 before its wrapper too).
    __asm__ volatile("" : "+r"(src), "+r"(dst), "+r"(n));

    BENCH_START();
    for (uint32_t i = 0; i < n; i++)
        dst[i] = src[i];
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int i = 0; i < 6; i++) {
        if (dst32[i] != expected[i]) {
            result = CHECK_FAIL(i);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
