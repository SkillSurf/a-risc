/*
  Engineer    : Abarajithan G
  Company     : -
  Create Date : 31-July-2022
  Design Name : A-RISC cpu
  Description : Aba's Custom RISC CPU in 99 Lines of Code
*/

timeunit 1ns/1ps;

module cpu #(NUM_GPR = 8)
(
  input  logic clk, rstn, start,
  output logic idle,
  
  // dout, din are named wrt RAM, not CPU
  input  logic [15:0] iram_dout,  // 16 bit instruction
  output logic [7 :0] iram_addr,  // Max RAM depth: 256 words
  output logic        iram_write,

  // dout, din are named wrt RAM, not CPU
  input  logic [7 :0] dram_dout,
  output logic [7 :0] dram_din,
  output logic [7 :0] dram_addr,  // Max RAM depth: 256 words
  output logic        dram_write
);
  localparam NUM_ADDRESSIBLE_REGISTERS = 4 + NUM_GPR,
             W_REG_ADDR = $clog2(NUM_ADDRESSIBLE_REGISTERS);

  // Machine code encodings for instruction opcodes
  localparam bit [7:0] I_END=0, I_ADD=1, I_SUB=2, I_MUL=3, I_DV2=4, I_NOT=5, 
                       I_LDC=6, I_LDM=7, I_MVA=8, I_MVR=9, I_STM=10, I_JMZ=11, I_JMN=12;
  
  // Register addressing
  localparam bit [W_REG_ADDR-1:0] R_AC=0, R_DIN=1, R_OPR=2, R_ADR=3;

  // 8-bit processor: All registers are 8 bits
  logic signed [7:0] ac, bus, alu_out, opr, adr, pc, pc_next, opc, din;
  logic [NUM_ADDRESSIBLE_REGISTERS-1:0] reg_en;


  //*** ALU (Arithmetic Logic Unit)

  localparam W_ALU_SEL = 3;
  logic [W_ALU_SEL-1:0] alu_sel;
  always_comb
    case (alu_sel)
      // Note: alu_sel encodings directly overlap with corresponding ISA
      //       For simpler design
      I_ADD  : alu_out = ac + bus;
      I_SUB  : alu_out = ac - bus;
      I_MUL  : alu_out = ac * bus;
      I_DV2  : alu_out = bus/2;
      I_NOT  : alu_out = !bus;
      default: alu_out = bus; // pass if 0
    endcase


  //*** Accumulator

  register #(8,0) AC (clk, rstn, reg_en[R_AC], alu_out, ac);
  // zero and negative flags, used for jump (branching & looping)
  wire z_ac=(ac==0), n_ac=(ac<0);


  //*** GPR (General Purpose Registers)

  logic signed [7:0] gpr [NUM_GPR];

  for (genvar i=0; i<NUM_GPR; i++)
    register #(8,0) REG (clk, rstn, reg_en[i+4], ac, gpr[i]);


  //*** Memory Control

  assign iram_write = 0;
  assign iram_addr = pc_next;
  assign {opr, opc} = iram_dout;

  register #(8,0) ADR (clk, rstn, reg_en[R_ADR], ac, adr);

  assign din = dram_dout;
  assign dram_addr = adr;
  assign dram_din = ac;


  //*** Bus
  
  logic signed [W_REG_ADDR-1:0] bus_sel;
  // Order should match with register addressing
  wire signed [7:0] bus_in [NUM_ADDRESSIBLE_REGISTERS] = {ac, din, opr, adr, gpr};
  assign bus = bus_in[bus_sel];


  //*** State Machine: (Fetch, Decode, Execute)

  localparam bit [1:0] S_IDLE=0, S_FETCH=1, S_DECODE_EXECUTE=2;
  logic [1:0] state, state_next;
  register #(2,S_IDLE) STATE (clk, rstn, 1'b1, state_next, state);
  always_comb
    case (state)
      S_IDLE           : state_next = start ? S_FETCH : S_IDLE;
      S_FETCH          : state_next = S_DECODE_EXECUTE;
      S_DECODE_EXECUTE : state_next = opc == I_END ? S_IDLE : S_FETCH;
    endcase

  //*** PC (Program Counter)
  // Here, pc holds addr of current instruction.
  //       pc_next = iram_addr = address of next instruction

  logic pc_en;
  register #(8,-1) PC (clk, rstn, pc_en, pc_next, pc);
  assign idle  = state == S_IDLE;
  assign pc_en = state == S_DECODE_EXECUTE;
  

  //*** Instruction Decoder

  always_comb begin
    // Last assignment wins inside an always_comb
    // handy way to write a combinational decoder
    {bus_sel, alu_sel, reg_en, dram_write} = '0;
    pc_next = pc + 1;

    if (state == S_DECODE_EXECUTE)
      case (opc)
        I_END  : pc_next       = 0;
        I_LDM  : dram_write    = 0;  // DIN <- DRAM[ADR]
        I_STM  : dram_write    = 1;  // DRAM[ADR] <- AC
        I_LDC  : begin               // AC <- OPR
                  bus_sel      = R_OPR; // bus <- OPR
                  reg_en[R_AC] = 1;     // AC  <- alu_out=bus (alu passes by default)
                 end
        I_MVA  : begin               // AC <- R[OPR]
                  bus_sel      = opr;   // bus <- R[OPR]
                  reg_en[R_AC] = 1;     // AC  <- alu_out=bus (alu passes by default)
                 end
        I_MVR  : reg_en[opr] = 1;    // R[opr] <- AC; one hot decoding for reg enables
        I_JMZ  : if (z_ac) pc_next = opr; // if (AC=0) load IRAM[OPR]
        I_JMN  : if (n_ac) pc_next = opr; // if (AC<0) load IRAM[OPR]
        
        // Default case covers all arithmetic & logic instructions
        // Possible since we overlapped their encodings with alu_sel
        default: begin               // AC <- AC (opr) bus
                  bus_sel = opr;          // bus <- R[OPR]
                  alu_sel = opc;          // alu_sel = opcode; select AL operation
                  reg_en[R_AC] = 1;       // AC <- alu_out
                 end
      endcase
  end
endmodule