# A Custom RISC CPU in 99 Lines of SystemVerilog

A-RISC is built as a teaching material, to introduce computer architecture & implementation to newbies. Objectives of the design are as follows:

* Full featured: ability to run any algorithm, such as prime finding, basic image processing...etc.
* Simple architecture: 8-bit data & addresses
* Contains all components of a processor for teaching: PC, state machine (fetch, decode, execute), ALU, general purpose registers, bus
* Reduced Instruction Set: Each instruction is 16-bit, does exactly one job in one clock cycle (in cpu v1)
* Easily pipelinable: Each instruction takes only one clock, can be pipelined later
* Easy implementation: Just 99 lines of SystemVerilog code

To achieve the above objectives, design of cpu-v1 trades-off the following:

* SRAMs with 1 clock latency
* Relatively long combinational paths

CPU-v3 will be a slightly modified version of v1, with a 6-stage pipeline, SRAMs with 2 clock latency, and short combinational paths for high frequency implementation.

## Instruction Set Architecture

Basic ISA with 12 instructions. Each instruction has 2 bytes, fetched through a 16-bit bus every clock. Bit fields of instructions are as follows:

```
  _________________
  |_4_|_4_|_4_|_4_|

- END              : stop execution
- ADD  rd  ra  rb  : R[rd]     <- R[a] + R[b]
- SUB  rd  ra  rb  : R[rd]     <- R[a] - R[b]
- MUL  rd  ra  rb  : R[rd]     <- R[a] * R[b]
- DV2  rd  ra      : R[rd]     <- R[a]/2
- NOT  rd  ra      : R[rd]     <- logical_not(R[a])
- LDC  rd  const   : R[rd]     <- const
- LDM              : DIN       <- DRAM[ADR]
- STM      ra      : DRAM[ADR] <- R[ra]
- MOV  rd  ra      : R[rd]     <- R[rx]
- BNE      ra  rb  : branch to IRAM[JAD] if R[ra] != R[rb]
- BLT      ra  rb  : branch to IRAM[JAD] if R[ra] <  R[rb] 
```

## Register Addressing (regaddr)

CPU is parametrized with `NUM_GPR < 11` number of General Purpose Registers.
The following addressing scheme is used to read from & write to registers.

```
* 0           : 0   (constant wire)
* 1           : 1   (constant wire)
* 2           : DIN (dout wire of DRAM)
* 3           : CON (const wire of current instruction, for LDC)
* 4           : ADR (address register for DRAM)
* 5           : JAD (jump address register for IRAM)
* 6:NUM_GPR+5 : General Purpose Registers
```

## Architecture (draft)


