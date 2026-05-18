# RiscvRVVE Walkthrough

## Folder Structure

```
riscvRVVE/
├── core/riscv/          ← the actual CPU RTL (Verilog)
├── top_tcm_axi/         ← PRIMARY top — used by all tests
├── top_cache_axi/       ← alternative top with caches
├── top_tcm_wrapper/     ← thin wrapper variant of TCM top
├── isa_sim/             ← C++ software simulator (co-sim)
├── tests/               ← your assembly test programs (.s)
└── doc/                 ← misc docs
```

---

## The Core Pipeline (`core/riscv/`)

`riscv_core.v` is the top-level that wires all the pipeline stages together.

### Scalar stages (upstream RV32IM)

| Module | Role |
|---|---|
| `riscv_fetch.v` | Instruction fetch — drives the `mem_i_*` bus, handles PC, branch redirects |
| `riscv_decode.v` | Decode stage — splits raw instruction into opcode fields, decides what kind of op it is |
| `riscv_decoder.v` | Decoder ROM / combinational decode helper (called from decode stage) |
| `riscv_issue.v` | Issue / scoreboard — checks data hazards, stalls until operands are ready, dispatches to execution units |
| `riscv_exec.v` | Integer ALU execution (ADD, XOR, shifts, branches, etc.) |
| `riscv_alu.v` | Pure-combinational ALU instantiated by riscv_exec |
| `riscv_lsu.v` | Scalar load/store unit — drives the `mem_d_*` data bus |
| `riscv_multiplier.v` | Multi-cycle MUL/MULH unit |
| `riscv_divider.v` | Multi-cycle DIV/REM unit |
| `riscv_csr.v` + `riscv_csr_regfile.v` | CSR read/write, `dscratch` (used to halt sim), `mtvec`, `mepc`, etc. |
| `riscv_regfile.v` | 32×32 scalar register file (x0–x31) |
| `riscv_mmu.v` | Optional MMU (disabled by parameter in this setup) |
| `riscv_pipe_ctrl.v` | Pipeline flush/stall control signals |
| `riscv_defs.v` | Shared defines/parameters — opcode encodings, function codes. **Touch this when adding new vector instruction encodings.** |

### RVVE vector extension (the 4 `riscv_v_*` files)

| Module | Role |
|---|---|
| `riscv_v_regfile.v` | 32 vector registers, each VLEN bits wide (default 128b = four 32-bit elements). 1 write port, 2 read ports. |
| `riscv_v_alu.v` | Pure-combinational vector ALU. Takes two VLEN operands and a 4-bit function code, computes element-wise result (add, sub, mul, etc.). No state. |
| `riscv_v_exec.v` | Vector execute stage. Registers the decoded opcode, calls `riscv_v_alu`, writes back to `riscv_v_regfile`. Also handles `vmv.x.s` (move vector element → scalar register). |
| `riscv_v_lsu.v` | Vector load/store unit. Iterates through VLEN/ELEN = 4 elements sequentially, issuing one scalar memory transaction per cycle. Has its own `busy_o` signal that stalls the pipeline until all elements are done. |

The decode hooks for these are in `riscv_decode.v` and `riscv_defs.v`.

---

## Top-Level Modules

### 1. `top_tcm_axi` — the one used by tests (`top_tcm_axi/src_v/riscv_tcm_top.v`)

```
riscv_tcm_top
 ├── riscv_core        ← the CPU
 ├── dport_mux         ← arbitrates CPU data port between TCM and AXI
 ├── tcm_mem           ← 64KB dual-ported SRAM (I-port + D-port)
 │    ├── tcm_mem_pmem ← program memory (holds your .elf)
 │    └── tcm_mem_ram  ← data/stack
 └── dport_axi         ← bridges CPU data port to AXI4 slave (for peripherals above 64KB)
```

Boot address is `0x2000`. The TCM sits at `0x0000_0000`. The ELF is loaded into TCM by the testbench before simulation starts. The AXI4-Lite master is how the testbench injects the ELF via an AXI slave.

### 2. `top_cache_axi` — alternative, not used by tests (`top_cache_axi/src_v/riscv_top.v`)

```
riscv_top
 ├── riscv_core
 ├── icache     ← instruction cache (direct-mapped, AXI4 master)
 └── dcache     ← data cache (write-back, AXI4 master)
```

Meant for systems where SDRAM is behind an AXI bus. No TCM — the external memory system provides backing store. This is the "big system" config; useful when targeting FPGA with external RAM.

### 3. `top_tcm_wrapper` (`top_tcm_wrapper/riscv_tcm_wrapper.v`)

A thin wrapper around the same TCM primitives (`tcm_mem`, `dport_axi`, `dport_mux`) without the core instantiated — useful as a reusable memory subsystem block in a larger SoC where the core is brought in separately.

---

## The Simulation Flow

```
tests/NAME.s
    │
    ▼  riscv64-unknown-elf-gcc -march=rv32iv
tests/NAME.elf   (text @ 0x2000)
    │
    ▼  top_tcm_axi/tb/build/test.x -f NAME.elf
         │
         ├── SystemC + Verilator simulation of riscv_tcm_top
         ├── isa_sim (C++ co-simulator) runs in parallel, cycle-by-cycle
         ├── AXI slave loads ELF into TCM at startup
         ├── CPU runs, VCD waveforms → top_tcm_axi/tb/sim.vcd
         └── test exits via:  csrw dscratch, x0  →  sim_exit(0)
                                        │
                                        ▼
                                   PASS / FAIL printed
```

The co-simulator (`isa_sim/`) is a pure-software RISC-V model that runs the same ELF alongside the RTL. Every instruction, both models advance one step. If their register/memory state diverges, the testbench reports a mismatch — this is how functional bugs in the RTL are caught automatically.

After `make run`, GTKWave opens `top_tcm_axi/tb/verilator.gtkw` so you can inspect waveforms.

### Build & test commands (from `tests/`)

| Command | What it does |
|---|---|
| `make NAME.elf` | Assemble `NAME.s` and disassemble it |
| `make run NAME.elf` | Build (if stale) then run through the testbench, open GTKWave |
| `make dump NAME.elf` | Disassemble an already-built ELF |
| `make clean NAME.s` | Remove only that test's ELF |
| `make build` | Force full Verilator + SystemC testbench rebuild — **required after any `.v` or `tb/` edit** |

---

## Adding a New Vector Instruction

1. Add encoding to `riscv_defs.v`
2. Decode it in `riscv_decode.v` / `riscv_decoder.v`
3. Implement in `riscv_v_exec.v` or `riscv_v_lsu.v` (add ALU opcode to `riscv_v_alu.v` if needed)
4. Write a test in `tests/` (e.g. `tests/vnewop.s`)
5. `cd tests && make build && make run vnewop.elf`
