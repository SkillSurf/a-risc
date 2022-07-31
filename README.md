# Aba's Custom RISC CPU in 100 Lines of Code

A-RISC is built as a teaching material, to introduce computer architecture & implementation to newbies. Objectives of the design are as follows:

* Full featured: ability to run any algorithm, such as prime finding, basic image processing...etc.
* Simple architecture: 8-bit data & addresses, everything goes to AC, comes from AC.
* Reduced Instruction Set: Each instruction is 16-bit, does exactly one job in one clock cycle (in cpu v1)
* Easily pipelinable: Each instruction takes only one clock, can be pipelined later
* Easy implementation: Just 100 lines of code

To achieve the above objectives, design of cpu-v1 allows the following drawbacks:

* SRAMs with 1 clock latency
* Long combinational paths

CPU-v3 will be a slightly modified version of v1, with a 6-stage pipeline, SRAMs with 2 clock latency, and short combinational paths for high frequency implementation.

## ISA

Basic ISA with 13 instructions. Each instruction has 2 bytes, fetched through a 16 bit bus every clock. 

```
* END         : stop execution
* ADD regaddr : AC <- AC + R[regaddr]
* SUB regaddr : AC <- AC - R[regaddr]
* MUL regaddr : AC <- AC * R[regaddr]
* DV2         : AC <- AC/2
* NOT regaddr : logical_not(R[regaddr])
* LDK const   : AC <- const
* LDM xxxxx   : DRAM[ADR] <- DIN
* MVA regaddr : AC <- R[regaddr]
* MVR regaddr : R[regaddr] <- AC
* STM xxx     : DRAM[ADR] <- AC
* JMZ memaddr : branch to memaddr if A is zero
* JMN memaddr : branch to memaddr is A is negative 
```

## Register Addressing

```
* 0     : AC  (accumulator)
* 1     : DIN (dout wire of DRAM)
* 2     : OPR (operand wire of current instruction)
* 3     : ADR (address register for DRAM)
* 4:N+3 : General Purpose Registers
```
