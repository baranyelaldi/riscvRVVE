// matmul_n32_scalar.c — RV32IM scalar baseline for tests/matmul_n32.s
//
// Same inputs (A[i][j] = i+1, B = A^T column-major), same output location
// (C row-major at 0x8000), same algorithm: one dot product per C cell over
// contiguous rows of A and columns of B. Uses the core's hardware multiplier
// (SUPPORT_MULDIV=1), so the baseline is not handicapped by a software mul.
//
// Self-check (not in the vector original, which is checked by inspection):
// C[i][j] = N * (i+1) * (j+1); on mismatch reports the flat index i*N+j.
#include "bench.h"

#define N 32

extern const int32_t mm_A[N * N];
extern const int32_t mm_B[N * N];

int main(void)
{
    const int32_t *A = mm_A;
    const int32_t *B = mm_B;
    int32_t       *C = (int32_t *)0x8000;
    __asm__ volatile("" : "+r"(A), "+r"(B), "+r"(C));

    BENCH_START();
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            const int32_t *a = A + i * N;
            const int32_t *b = B + j * N;
            int32_t sum = 0;
            for (int k = 0; k < N; k++)
                sum += a[k] * b[k];
            C[i * N + j] = sum;
        }
    }
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int i = 0; i < N && result == CHECK_PASS; i++) {
        for (int j = 0; j < N; j++) {
            if (C[i * N + j] != N * (i + 1) * (j + 1)) {
                result = CHECK_FAIL(i * N + j);
                break;
            }
        }
    }
    RESULT_CHECK = result;
    return 0;
}
