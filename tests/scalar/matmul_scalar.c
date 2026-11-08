// matmul_scalar.c — RV32IM scalar baseline for tests/matmul_selfcheck.s (N=4)
//
// Same inputs, same output (C = A x A^T row-major at 0x4000), same expected
// values. N is read at run time, matching the vector kernel, which is the
// generic any-N version (matmul_var_anyN.s); a compile-time N=4 would let the
// compiler fully unroll the inner loop and measure the size, not the ISA.
#include "bench.h"

extern const int32_t  mm4_A[];
extern const int32_t  mm4_B[];
extern const uint32_t mm4_n;

static const int32_t expected[16] = {
     30,  70, 110, 150,
     70, 174, 278, 382,
    110, 278, 446, 614,
    150, 382, 614, 846
};

int main(void)
{
    const int32_t *A = mm4_A;
    const int32_t *B = mm4_B;
    int32_t       *C = (int32_t *)0x4000;
    uint32_t       n = *(volatile const uint32_t *)&mm4_n;
    __asm__ volatile("" : "+r"(A), "+r"(B), "+r"(C), "+r"(n));

    BENCH_START();
    for (uint32_t i = 0; i < n; i++) {
        for (uint32_t j = 0; j < n; j++) {
            const int32_t *a = A + i * n;
            const int32_t *b = B + j * n;
            int32_t sum = 0;
            for (uint32_t k = 0; k < n; k++)
                sum += a[k] * b[k];
            C[i * n + j] = sum;
        }
    }
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int i = 0; i < 16; i++) {
        if (C[i] != expected[i]) {
            result = CHECK_FAIL(i);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
