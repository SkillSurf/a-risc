# A Custom RISC CPU in 99 Lines of SystemVerilog

A-RISC is built as a teaching material, to introduce computer architecture & implementation to newbies. Objectives of the design are as follows:

* Full featured: ability to run any algorithm, such as prime finding, basic image processing...etc.
* Simple architecture: 8-bit data & addresses; everything goes to AC & comes from AC
* Contains all components of a processor for teaching: PC, state machine (fetch, decode, execute), ALU, general purpose registers, bus
* Reduced Instruction Set: Each instruction is 16-bit, does exactly one job in one clock cycle (in cpu v1)
* Easily pipelinable: Each instruction takes only one clock, can be pipelined later
* Easy implementation: Just 99 lines of SystemVerilog code

To achieve the above objectives, design of cpu-v1 trades-off the following:

* SRAMs with 1 clock latency
* Relatively long combinational paths

CPU-v3 will be a slightly modified version of v1, with a 6-stage pipeline, SRAMs with 2 clock latency, and short combinational paths for high frequency implementation.

## Instruction Set Architecture

Basic ISA with 13 instructions. Each instruction has 2 bytes, fetched through a 16-bit bus every clock. Opcodes and operands are 8 bits each. Instruction that do not require operands allow any value (don't care) for operand part.

```
* END         : stop execution
* ADD regaddr : AC  <- AC + R[regaddr]
* SUB regaddr : AC  <- AC - R[regaddr]
- MUL regaddr : AC  <- AC * R[regaddr]
- DV2         : AC  <-      R[regaddr]/2
- NOT regaddr : AC  <- logical_not(R[regaddr])
* LDC const   : AC  <- const
* MVA regaddr : AC  <- R[regaddr]
* MVR regaddr : R[regaddr] <- AC
* LDM         : DIN <- DRAM[ADR]
* STM         : DRAM[ADR]  <- AC
- JMZ memaddr : branch to IRAM memaddr if A is zero
- JMN memaddr : branch to IRAM memaddr if A is negative 
```

## Register Addressing (regaddr)

CPU is parametrized with `NUM_GPR` number of General Purpose Registers.
The following addressing scheme is used to read from & write to registers.

```
* 0           : AC  (accumulator)
* 1           : DIN (dout wire of DRAM)
* 2           : OPR (operand wire of current instruction)
* 3           : ADR (address register for DRAM)
* 4:NUM_GPR+3 : General Purpose Registers
```

## Architecture (draft)

![arisc](https://user-images.githubusercontent.com/26372005/182097673-9a089f6a-7f4c-4e8d-81fd-e0a5ea3c9bdd.png)


