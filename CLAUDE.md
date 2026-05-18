# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A fork of the `ultraembedded/riscv` 32-bit RV32IMZicsr core (Verilog) with a custom **vector extension (RVVE)** bolted on. The vector pipeline lives alongside the scalar pipeline in [core/riscv/](core/riscv/) and adds `riscv_v_alu.v`, `riscv_v_exec.v`, `riscv_v_lsu.v`, `riscv_v_regfile.v` — these are instantiated from [riscv_core.v](core/riscv/riscv_core.v) and share the issue/decode infrastructure with the scalar core. Tests target `rv32iv`.

Upstream README content (cache/AXI/top descriptions, ISA spec links) is in [README.md](README.md) — don't duplicate it here.

## Repository layout

- [core/riscv/](core/riscv/) — RV32IM core + RVVE vector extension (the `riscv_v_*.v` files are the local additions)
- [isa_sim/](isa_sim/) — C++ instruction set simulator, also built as `libisa_sim.a` and linked into the SystemC testbench for co-simulation
- [top_tcm_axi/](top_tcm_axi/) — **primary** top-level used by the test flow: core + 64KB dual-ported TCM + AXI4 slave (memory load) + AXI4-Lite master (peripherals); SystemC/Verilator testbench in `tb/`
- [top_cache_axi/](top_cache_axi/) — alternative top with I/D caches and two AXI4 masters
- [top_tcm_wrapper/](top_tcm_wrapper/) — wrapper variant of the TCM top
- [tests/](tests/) — RVVE assembly tests (`.s`) that drive the TCM top via the Verilator testbench

## Build & test workflow

The day-to-day flow is driven by [tests/Makefile](tests/Makefile), which assembles a `.s` test and runs it through the prebuilt SystemC testbench at `top_tcm_axi/tb/build/test.x`. Toolchain expected on `$PATH`: `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-objdump`, Verilator, SystemC (`SYSTEMC_HOME`, defaults to `/usr` in `tests/Makefile build`, `/usr/local/systemc-2.3.1` in the upstream tb makefile).

From [tests/](tests/):

```bash
make NAME.elf        # assemble NAME.s at .text=0x2000 with -march=rv32iv -mabi=ilp32 + auto-disassemble
make run NAME.elf    # build (if stale) + run via testbench; auto-opens GTKWave if not already running
make dump NAME.elf   # disassemble an existing elf
make clean NAME.s    # remove only that test's elf
make build           # force full Verilator + tb rebuild — REQUIRED after editing any .v under core/ or any tb/ source
```

Two-argument targets (`run`/`dump`/`clean`) accept either `NAME.s` or `NAME.elf`. `make build` shells into `top_tcm_axi/tb` with `SYSTEMC_HOME=/usr LIB_OPT= EXTRA_CFLAGS="-Wno-error -L/usr/lib/x86_64-linux-gnu"` and forces `make -B` because the upstream tb's `build` target collides with its own `build/` directory.

Boot address is `0x2000` (linker `-Ttext=0x2000`); TCM is 64KB at `0x0000_0000`.

Lower-level entry points if you need them:
- [top_tcm_axi/tb/](top_tcm_axi/tb/) — `make` (full Verilator+tb build), `make run` (runs `../../isa_sim/images/basic.elf`); cascades through `makefile.generate_verilated` → `makefile.build_verilated` → `makefile.build_sysc_tb`
- [isa_sim/](isa_sim/) — `make` builds standalone `riscv-sim` + `libisa_sim.a`; deps: `libelf-dev binutils-dev`
- [top_cache_axi/tb/](top_cache_axi/tb/) — analogous flow for the cached top

## Test halt / simulator I/O convention

Assembly tests terminate by writing to CSR `dscratch` (see [isa_sim/README.md](isa_sim/README.md)):
- `csrw dscratch, x0` (with high byte `0x00`) — `sim_exit(0)`
- High byte `0x01` — `sim_putc` (char in low byte)

This is recognized by both the ISA sim and the SystemC testbench, so every test should end with a `csrw dscratch,...` followed by an infinite loop.

## Conventions worth knowing

- Verilog is **Verilog-2001**, Verilator-clean, FPGA-friendly — keep new RTL in the same style (no SystemVerilog-only constructs in the scalar/vector pipeline files).
- Vector RTL lives in `core/riscv/riscv_v_*.v` and is instanced from `riscv_core.v`; decode hooks are in `riscv_decode.v` / `riscv_decoder.v` / `riscv_defs.v`. When adding a new vector instruction, expect to touch decode + the relevant `riscv_v_*` unit and add a `.s` test under `tests/`.
- Tests are flat in [tests/](tests/) — one `.s` per test, no subdirs. Naming examples: `vadd.s`, `vlsu_smoke.s`, `valu_smoke.s`, `matmul.s`, `vmv_x_s2.s`.
- After any RTL or tb edit, run `make build` from `tests/` before `make run NAME.elf` — the per-test rule does **not** rebuild the testbench.
- VCD output lands in `top_tcm_axi/tb/` next to `verilator.gtkw`; `make run` auto-launches GTKWave only if one isn't already running.
- Working branch is `baran_linux`; upstream is `master`.
