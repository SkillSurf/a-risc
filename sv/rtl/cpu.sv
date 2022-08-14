/*
  Engineer    : Abarajithan G
  Company     : -
  Create Date : 31-July-2022
  Design Name : A-RISC cpu
  Description : A Custom RISC CPU in 99 Lines of Code
*/

`timescale 1ns/1ps

module cpu #(NUM_GPR = 8)
(
  input  logic clk, rstn, start,
  output logic idle,
  // dout, din are named wrt RAM, not CPU
  input  logic [15:0] iram_dout,  // 16 bit instruction
  input  logic [7 :0] dram_dout,

  output logic [7 :0] iram_addr,  dram_din, dram_addr,
  output logic        dram_write
);
  localparam NUM_ADDRESSIBLE_REGISTERS = 6 + NUM_GPR,
             W_REG_ADDR = $clog2(NUM_ADDRESSIBLE_REGISTERS);

  // Machine code encodings for instruction opcodes
  localparam bit [3:0] I_END=0, I_ADD=1, I_SUB=2, I_MUL=3, I_DV2=4, 
                       I_LDM=5, I_STM=6, I_MVR=7, I_MVI=8, I_BEQ=9, I_BLT=10;
  
  // Register addressing
  localparam bit [W_REG_ADDR-1:0] R_DI=2, R_IM=3, R_AR=4, R_JR=5;

  // 8-bit processor: All registers are 8 bits
  logic signed [7:0] bus_a, bus_b, alu_out, ar, jr, im, pc, pc_next, di;
  logic        [3:0] opcode, rd, ra, rb;
  logic [NUM_ADDRESSIBLE_REGISTERS-1:0] reg_en;


  //*** ALU (Arithmetic Logic Unit)

  localparam W_ALU_SEL = 3;
  logic [W_ALU_SEL-1:0] alu_sel;
  always_comb
    case (alu_sel)
      // Note: alu_sel encodings directly overlap with corresponding ISA encodings
      //       to simplify the instruction decoder
      I_ADD  : alu_out = bus_a + bus_b;
      I_SUB  : alu_out = bus_a - bus_b;
      I_MUL  : alu_out = bus_a * bus_b;
      I_DV2  : alu_out = bus_a/2;
      default: alu_out = bus_a; // pass a if 0
    endcase


  //*** GPR (General Purpose Registers)

  logic signed [0:NUM_GPR-1][7:0] gpr;

  for (genvar i=0; i<NUM_GPR; i++)
    register #(8,0) REG (clk, rstn, reg_en[i+6], alu_out, gpr[i]);


  //*** Memory Control

  assign iram_addr = pc_next;
  assign {rb, ra, rd, opcode} = iram_dout;
  assign im = {ra, rb};

  register #(8,0) AR  (clk, rstn, reg_en[R_AR], alu_out, ar);
  register #(8,0) JR  (clk, rstn, reg_en[R_JR], alu_out, jr);

  assign {di, dram_addr, dram_din} = {dram_dout, ar, alu_out};


  //*** Bus
  
  logic [W_REG_ADDR-1:0] bus_a_sel, bus_b_sel;
  // Order should match with register addressing
  wire signed [0:NUM_ADDRESSIBLE_REGISTERS-1][7:0] bus_a_in = {8'd0, 8'd1, di, im, ar, jr, gpr};
  wire signed [0:NUM_ADDRESSIBLE_REGISTERS-1][7:0] bus_b_in = {8'd0, 8'd1, di, im, ar, jr, gpr};
  
  assign bus_a = bus_a_in[bus_a_sel]; // simple multiplexed bus
  assign bus_b = bus_b_in[bus_b_sel]; // simple multiplexed bus


  //*** State Machine: (Fetch, Decode, Execute)

  localparam bit [1:0] S_IDLE=0, S_FETCH=1, S_DECODE_EXECUTE=2;
  logic [1:0] state, state_next;

  always_comb
    case (state)
      S_IDLE           : state_next = start ? S_FETCH : S_IDLE;
      S_FETCH          : state_next = S_DECODE_EXECUTE;
      S_DECODE_EXECUTE : state_next = opcode == I_END ? S_IDLE : S_FETCH;
    endcase

  register #(2,S_IDLE) STATE (clk, rstn, 1'b1, state_next, state);

  //*** PC (Program Counter)
  // Here, pc holds addr of current instruction.
  //       pc_next = iram_addr = address of next instruction
  //       jump_success register tells to branch to JDR in the next clock cycle

  logic pc_en, jump_success, jump_success_next;
  register #(8,-1) PC (clk, rstn, pc_en, pc_next,   pc);
  register #(1, 0) JS (clk, rstn, pc_en, jump_success_next, jump_success);
  
  assign idle  = state == S_IDLE;
  assign pc_en = state == S_DECODE_EXECUTE;
  

  //*** Instruction Decoder

  always_comb begin

    // Last assignment wins inside an always_comb
    // handy way to write a combinational decoder

    {alu_sel, reg_en, dram_write, jump_success_next} = '0;
    bus_a_sel = ra;
    bus_b_sel = rb;
    pc_next   = jump_success ? jr : pc + 1;

    if (state == S_DECODE_EXECUTE)
      case (opcode)
        I_END  : pc_next     = 0;
        I_LDM  : dram_write  = 0;  // DI <- DRAM[AR]
        I_STM  : dram_write  = 1;  // DRAM[AR] <- A[ra]  (alu passes a by default)
        I_MVI  : begin               // R[rd] <- IM
                  bus_a_sel  = R_IM; // bus_a  <- IM
                  reg_en[rd] = 1;     // AR[rd] <- bus_a (alu passes a by default)
                 end
        I_MVR  : reg_en[rd]  = 1;  // R[rd] <- A[ra] (alu passes a by default)
        I_BEQ  : begin               // if R[ra] != R[rb], pc_next = JR in next clock
                  alu_sel    = I_SUB;   
                  jump_success_next  = (alu_out == 0);
                 end
        I_BLT  : begin               // if R[ra] <  R[rb], pc_next = JR in next clock
                  alu_sel    = I_SUB;   
                  jump_success_next  = (alu_out <  0);
                 end
        
        // Default case covers all arithmetic & logic instructions
        // Possible since we overlapped their encodings with alu_sel
        default: begin               // R[rd] <- R[ra] (opr) R[rb]
                  alu_sel = opcode;     // select AL operation
                  reg_en[rd] = 1;       // R[rd] <- alu_out
                 end
      endcase
  end
endmodule