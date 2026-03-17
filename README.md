# RISC-TOY with Custom IP

A custom 32-bit RISC processor implemented in Verilog, featuring a 5-stage pipeline and an integrated 4×4 systolic MAC array accelerator IP for matrix multiplication.

> **Team 14**
> - 2020104194 · Nam InSu
> - 2021104344 · Ju Hwansu
> - 2023104146 · Gu miNju

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Instruction Set](#instruction-set)
4. [Custom IP — 4×4 MAC Array](#custom-ip--44-mac-array)
5. [Pipeline Hazard Handling](#pipeline-hazard-handling)
6. [File Structure](#file-structure)
7. [Simulation](#simulation)

---

## Overview

**RISC-TOY** is a 32-bit RISC processor designed from scratch in Verilog. It executes a custom instruction set across a classic 5-stage pipeline (IF → ID → EX → MEM → WB) and exposes a dedicated memory-mapped interface to a **Custom IP** block — a 4×4 systolic array capable of signed 4-bit integer matrix multiplication.

Key highlights:
- 5-stage pipelined datapath with full forwarding and hazard detection
- Delay-slot branch/jump scheme (branch resolved in EX, jump resolved in ID)
- 32 general-purpose registers (R0 is hardwired to 0)
- Dedicated `STIP` / `LDIP` instructions for communicating with the Custom IP
- 4×4 systolic MAC array with clock gating for energy efficiency
- Supports both 4×4 and 3×3 (zero-padded) matrix modes

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         RISC_TOY (Top)                               │
│                                                                      │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                    │
│  │  IF  │→ │  ID  │→ │  EX  │→ │ MEM  │→ │  WB  │                    │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘                    │
│      ↑         ↑         ↑                                           │
│  HAZARD_UNIT  CONTROL  FORWARDING                                    │
│                                                                      │
│  INST_RAM ──→ IF stage         DATA_RAM ←──→ MEM stage               │
│                                    ↕                                 │
│                              CUSTOM_IP (4×4 MAC Array)               │
└──────────────────────────────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage | Module | Description |
|---|---|---|
| **IF** | `stage_IF.v` | Fetches instruction; computes PC+4; handles PC stall and flush |
| **ID** | `stage_ID.v` | Decodes instruction; reads register file; resolves jumps; sign-extends immediates |
| **EX** | `stage_EX.v` | Executes ALU operation; evaluates branch condition; computes memory address |
| **MEM** | `stage_MEM.v` | Drives data memory interface (load / store / IP access) |
| **WB** | `stage_WB.v` | Selects write-back result (ALU / memory read / PC+4 / PC) |

### Pipeline Registers

| Register | Module |
|---|---|
| IF/ID | `reg_IFID.v` |
| ID/EX | `reg_IDEX.v` |
| EX/MEM | `reg_EXMEM.v` |
| MEM/WB | `reg_MEMWB.v` |

---

## Instruction Set

All instructions are 32 bits wide. The opcode occupies bits `[31:27]`.

### R-Type Instructions

| Mnemonic | Opcode | Operation |
|---|---|---|
| `ADD`  | `00000` | Rd = Ra + Rb |
| `SUB`  | `00010` | Rd = Ra − Rb |
| `NEG`  | `00011` | Rd = −Ra |
| `NOT`  | `00100` | Rd = ~Ra |
| `AND`  | `00101` | Rd = Ra & Rb |
| `OR`   | `00111` | Rd = Ra \| Rb |
| `XOR`  | `01001` | Rd = Ra ^ Rb |
| `LSR`  | `01010` | Rd = Ra >> shamt (logical) |
| `ASR`  | `01011` | Rd = Ra >>> shamt (arithmetic) |
| `SHL`  | `01100` | Rd = Ra << shamt |
| `ROR`  | `01101` | Rd = Ra rotated right by shamt |

### I-Type Instructions

| Mnemonic | Opcode | Operation |
|---|---|---|
| `ADDI` | `00001` | Rd = Ra + imm17 |
| `ANDI` | `00110` | Rd = Ra & imm17 |
| `ORI`  | `01000` | Rd = Ra \| imm17 |
| `MOVI` | `01110` | Rd = imm17 |

### Jump Instructions

| Mnemonic | Opcode | Operation |
|---|---|---|
| `J`  | `01111` | PC = PC + imm22 (unconditional jump, resolved at ID) |
| `JL` | `10000` | R[rd] = PC+4 ; PC = PC + imm22 (jump-and-link) |

### Branch Instructions

Branch targets are register-indirect. The condition is tested against `R[rc]`.

| Mnemonic | Opcode | `cond[2:0]` | Description |
|---|---|---|---|
| `BR`  | `10001` | `001` always / `010` zero / `011` nonzero / `100` ≥0 / `101` <0 | Conditional branch (resolved at EX) |
| `BRL` | `10010` | same as above | Branch-and-link: R[rd] = PC+4 |

### Memory Instructions

| Mnemonic | Opcode | Operation |
|---|---|---|
| `ST`  | `10011` | Mem[Ra + imm17] = Rb |
| `STR` | `10100` | Mem[PC + imm22] = Ra |
| `LD`  | `10101` | Rd = Mem[Ra + imm17] |
| `LDR` | `10110` | Rd = Mem[PC + imm22] |

### Custom IP Interface Instructions

| Mnemonic | Opcode | Operation |
|---|---|---|
| `STIP` | `11000` | Write data to Custom IP via memory-mapped port |
| `LDIP` | `10111` | Read result from Custom IP via memory-mapped port |

> The `CONSIG` output bus carries the control word for the Custom IP.
> Bits `[2]`, `[1]`, `[0]` control `start`, `init`, and `mode (3×3)` respectively.
> Bits `[8]`, `[7:6]`, `[5:4]` control output readback, row index, and column index.

---

## Custom IP — 4×4 MAC Array

### Overview

`CUSTOM_IP.v` implements a **systolic array accelerator** that computes **C = A × B** for 4-bit signed integer matrices. It interfaces with the processor through a shared data-memory port.

```
IPIN  [31:0] ──→ ┌───────────────┐ ──→ IPOUT [31:0]
CON   [31:0] ──→ │   CUSTOM_IP   │
                 └───────┬───────┘
                 ┌───────▼───────┐
                 │ macarray_4x4  │  ← 4×4 grid of MAC PEs
                 └───────────────┘
```

### Key Parameters

| Parameter | Value |
|---|---|
| Input precision | 4-bit signed integer |
| Accumulator width | 20-bit signed |
| Array size | 4×4 Processing Elements |
| 3×3 mode | Supported (4th row/column forced to 0) |
| Data receive cycles | 8 (one 17-bit word per cycle) |
| Compute cycles | ~13 (systolic skewing included) |

### Control Word (`CON` bus)

| Bit | Signal | Description |
|---|---|---|
| `[0]` | `mode` | `1` = 3×3 mode, `0` = 4×4 mode |
| `[1]` | `init` | Active-high: clears buffers and MAC accumulators |
| `[2]` | `start` | Rising edge triggers data reception |
| `[8]` | `read_en` | Enable result readout |
| `[7:6]` | `row_sel` | Output row index (0–3) |
| `[5:4]` | `col_sel` | Output column index (0–3) |

### Data Flow

1. Assert `CON[2]` (start) → rising edge captured by the IP controller
2. Feed 8 × 17-bit input words through `IPIN` (buffers 0–3 = rows of A; buffers 4–7 = rows of B)
3. The IP automatically skews inputs into the systolic array and accumulates over ~11 cycles
4. Set `CON[8]=1` and `CON[7:4]` = {row, col} → read element C[row][col] from `IPOUT`

### MAC Processing Element (`MAC.v`)

Each PE performs a signed multiply-accumulate:

```
result <= result + (a_in × b_in)   // 20-bit signed accumulator
a_out  <= a_in                      // pass-through to right neighbour
b_out  <= b_in                      // pass-through to bottom neighbour
```

A **clock gating** cell (`clk_gate.v`) gates the accumulator clock when `enable & update_ready = 0`, reducing dynamic power during idle cycles.

### Systolic Array Topology (`macarray_4x4.v`)

```
      b_col0  b_col1  b_col2  b_col3
        │       │       │       │
a_row0─PE00───PE01───PE02───PE03
        │       │       │       │
a_row1─PE10───PE11───PE12───PE13
        │       │       │       │
a_row2─PE20───PE21───PE22───PE23
        │       │       │       │
a_row3─PE30───PE31───PE32───PE33
```

Data flows **rightward** along rows (A operands) and **downward** along columns (B operands). Each PE accumulates one partial product per clock cycle.

---

## Pipeline Hazard Handling

### Data Hazards — Forwarding (`FORWARDING.v`)

Full EX-MEM and MEM-WB forwarding is implemented for both source operands.

| `ForwardA / ForwardB` | Source |
|---|---|
| `2'b00` | ID/EX register output (no hazard) |
| `2'b01` | WB stage result (`Result_WB`) |
| `2'b10` | MEM stage ALU result (`ALU_result_MEM`) |

An additional WB→ID forwarding mux at the register-file read path handles the WB–ID boundary hazard.

### Load-Use Hazard — Stall (`HAZARD_UNIT.v`)

When a load instruction (`LD`, `LDR`, `LDIP`) is in the EX stage and its destination register matches a source register of the immediately following instruction, the pipeline is stalled for one cycle:
- PC write is suppressed
- IF/ID register is frozen
- A bubble (NOP) is injected into the ID/EX register

### Control Hazards — Branch & Jump

| Instruction | Resolved at | Strategy |
|---|---|---|
| `J`, `JL` | ID stage | 1-cycle delay slot; the instruction after the delay slot is flushed |
| `BR`, `BRL` | EX stage | 1-cycle delay slot; IF/ID is flushed when the branch is taken |

---

## File Structure

```
RISC-TOY-with-custom-IP/
├── RISC_TOY.v          # Top-level module (pipeline integration)
├── stage_IF.v          # Instruction Fetch stage
├── stage_ID.v          # Instruction Decode stage
├── stage_EX.v          # Execute stage (ALU + branch resolution)
├── stage_MEM.v         # Memory Access stage
├── stage_WB.v          # Write-Back stage
├── reg_IFID.v          # IF/ID pipeline register
├── reg_IDEX.v          # ID/EX pipeline register
├── reg_EXMEM.v         # EX/MEM pipeline register
├── reg_MEMWB.v         # MEM/WB pipeline register
├── CONTROL.v           # Instruction decoder / control signal generator
├── FORWARDING.v        # Data forwarding unit
├── HAZARD_UNIT.v       # Load-use hazard detection and stall logic
├── CUSTOM_IP.v         # Custom IP controller (matrix multiply orchestration)
├── macarray_4x4.v      # 4×4 systolic MAC array
├── MAC.v               # Single MAC processing element
├── clk_gate.v          # Integrated clock gate (ICG) cell
├── model.v             # Memory model (INST_RAM / DATA_RAM / REGFILE)
├── testbench.v         # Full-system simulation testbench
├── inst.hex            # Instruction memory initialisation file
└── mem.hex             # Data memory initialisation file
```

---

## Simulation

### Requirements

Any Verilog-2001 compatible simulator, such as **Icarus Verilog**, **ModelSim**, or **Vivado Simulator**.

### Running with Icarus Verilog

```bash
# Compile all sources
iverilog -o sim \
  testbench.v RISC_TOY.v \
  stage_IF.v stage_ID.v stage_EX.v stage_MEM.v stage_WB.v \
  reg_IFID.v reg_IDEX.v reg_EXMEM.v reg_MEMWB.v \
  CONTROL.v FORWARDING.v HAZARD_UNIT.v \
  CUSTOM_IP.v macarray_4x4.v MAC.v clk_gate.v \
  model.v

# Run the simulation
vvp sim
```

### Notes

- `inst.hex` must be present in the working directory; it is loaded into `INST_RAM` at simulation start.
- The testbench applies reset for 10 clock cycles, then releases reset and runs for 100 clock cycles before calling `$finish`.
- The default clock period is `10 ns` (half-period `5 ns`).
- The `CONSIG` bus connects `RISC_TOY` directly to `CUSTOM_IP`; no separate AXI or APB bus is required.
