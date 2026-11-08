// jacobi_1d_scalar.c — RV32IM scalar baseline for tests/jacobi_1d_selfcheck.s
//
// Same input A[0..15], same output B at 0x4000, same expected values.
// B[i] = A[i-1] + A[i] + A[i+1] for the 14 interior cells (no /3: matches the
// vector kernel). B[0] and B[N-1] are zeroed before the window, as in the
// vector version.
#include "bench.h"

extern const int32_t  jac_A[];
extern const uint32_t jac_n;

static const int32_t expected[16] = {
    0, 60, 90, 120, 150, 180, 210, 240,
    270, 300, 330, 360, 390, 420, 450, 0
};

int main(void)
{
    const int32_t *A = jac_A;
    int32_t       *B = (int32_t *)0x4000;
    uint32_t       n = *(volatile const uint32_t *)&jac_n;
    B[0]     = 0;
    B[n - 1] = 0;
    __asm__ volatile("" : "+r"(A), "+r"(B), "+r"(n) : : "memory");

    BENCH_START();
    for (uint32_t i = 1; i < n - 1; i++)
        B[i] = A[i - 1] + A[i] + A[i + 1];
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int i = 0; i < 16; i++) {
        if (B[i] != expected[i]) {
            result = CHECK_FAIL(i);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
