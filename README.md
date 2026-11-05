# RISC-V Processor

A RISC-V processor designed and implemented in SystemVerilog, featuring a custom datapath, control unit, and functional verification.

## Project Overview

This project implements a multi-cycle RISC-V processor using SystemVerilog. It covers processor architecture design, RTL implementation, functional simulation, and hardware verification.

## Key Features

- **ALU:** Arithmetic, logical, shift, and comparison operations, including status flags.
- **Instruction Decoder:** Instruction field extraction and immediate generation.
- **Register File:** Register storage with read and write operations.
- **Datapath:** Integration of processor components for instruction execution.
- **Control Unit:** FSM-based control of instruction execution.
- **Verification:** Module-level and system-level simulation using SystemVerilog testbenches.
- **FPGA:** Hardware implementation and verification on a Spartan-7 FPGA.

## Technologies

- SystemVerilog
- ModelSim / QuestaSim
- Xilinx Vivado
- Spartan-7 FPGA

## Project Structure

```text
riscv-processor/
├── riscv/       # RISC-V processor RTL source code
├── constr/      # FPGA constraints
├── firmware/    # Firmware and test programs
├── fpga/        # FPGA project files
├── report/      #  Datapath and control unit design diagrams (PDF)
└── README.md
```

