/* link.ld — scalar baselines: code + data in the TCM from the boot vector up
 * to 0x8000, the same placement the vector tests get from -Ttext=0x2000.
 * Each benchmark's output region must not overlap its own image:
 *   memcpy  : image ~0x2000-0x2200, output 0x4000
 *   matmul32: image ~0x2000-0x4200 (2x4 KB inputs), output 0x8000-0x9000
 * Fixed result words: 0x9000 cycles, 0x9010 instret, 0xA000 PASS/FAIL. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    TCM (rwx) : ORIGIN = 0x00002000, LENGTH = 24K
}

SECTIONS {
    .text   : { *(.text.start) *(.text*) } > TCM
    .rodata : { *(.rodata*) *(.srodata*) } > TCM
    .data   : { *(.data*) *(.sdata*) } > TCM
    .bss    : { *(.bss*) *(.sbss*) *(COMMON) } > TCM
}
