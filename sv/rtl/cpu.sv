// <100 code lines, 2h15 mins
timeunit 1ns/1ps;

module cpu #(NUM_GPR = 8)
(
  input  logic clk, rstn, start,
  output logic idle,

  input  logic [15:0] iram_dout,
  output logic [7 :0] iram_addr,
  output logic        iram_write,

  input  logic [7 :0] dram_dout,
  output logic [7 :0] dram_din,
  output logic [7 :0] dram_addr,
  output logic        dram_write
);
  localparam NUM_ADDRESSIBLE_REGISTERS = 4 + NUM_GPR,
             W_REG_ADDR = $clog2(NUM_ADDRESSIBLE_REGISTERS);

  localparam logic [1:0]            S_IDLE=0, S_FETCH=1, S_DECODE_EXECUTE=2;
  localparam logic [7:0]            I_END=0, I_ADD=1, I_SUB=2, I_MUL=3, I_DV2=4, I_NOT=5, I_LDK=6, I_LDM=7, I_MVA=8, I_MVR=9, I_STM=10, I_JMZ=11, I_JMN=12;
  localparam logic [W_REG_ADDR-1:0] B_AC=0, B_DIN=1, B_OPR=2, B_ADR=3;

  logic signed [7:0] ac, bus, alu_out, opr, adr, pc, pc_next, opc, din;
  logic [NUM_ADDRESSIBLE_REGISTERS-1:0] reg_en;


  //*** ALU (Arithmetic Logic Unit)

  localparam W_ALU_SEL = 3;
  logic [W_ALU_SEL-1:0] alu_sel;
  always_comb
    case (alu_sel)
      I_ADD  : alu_out = ac + bus;
      I_SUB  : alu_out = ac - bus;
      I_MUL  : alu_out = ac * bus;
      I_DV2  : alu_out = ac/2;
      I_NOT  : alu_out = !ac;
      default: alu_out = bus; // pass if 0
    endcase


  //*** Accumulator

  register #(8,0) AC (clk, rstn, reg_en[B_AC], alu_out, ac);
  wire z_ac = (ac == 0);
  wire n_ac = (ac < 0);


  //*** GPR (General Purpose Registers)

  logic signed [7:0] gpr [NUM_GPR];

  for (genvar i=0; i<NUM_GPR; i++)
    register #(8,0) REG (clk, rstn, reg_en[i+4], ac, gpr[i]);


  //*** Memory Control

  assign iram_write = 0;
  assign iram_addr = pc_next;
  assign {opr, opc} = iram_dout;

  assign din = dram_dout;
  assign {dram_addr, dram_din} = {adr, ac};
  register #(8,0) ADR (clk, rstn, reg_en[B_ADR], ac, adr);


  //*** Bus
  
  logic signed [W_REG_ADDR-1:0] bus_sel;
  wire signed [7:0] bus_in [NUM_ADDRESSIBLE_REGISTERS] = {ac, din, opr, adr, gpr};
  assign bus = bus_in[bus_sel];


  //*** Control unit

  logic pc_en;
  register #(8,-1) PC (clk, rstn, pc_en, pc_next, pc);

  logic [1:0] state, state_next;
  register #(2,S_IDLE) STATE (clk, rstn, 1'b1, state_next, state);
  always_comb
    case (state)
      S_IDLE           : state_next = start ? S_FETCH : S_IDLE;
      S_FETCH          : state_next = S_DECODE_EXECUTE;
      S_DECODE_EXECUTE : state_next = opc == I_END ? S_IDLE : S_FETCH;
    endcase

  assign idle  = state == S_IDLE;
  assign pc_en = state == S_DECODE_EXECUTE;
  
  //****** Instruction Decoder
  always_comb begin
    
    {bus_sel, alu_sel, reg_en, dram_write} = '0;
    pc_next = pc + 1;

    if (state == S_DECODE_EXECUTE)
      case (opc)
        I_END  : pc_next       = 0;
        I_LDM  : dram_write    = 0;
        I_STM  : dram_write    = 1;
        I_LDK  : begin 
                  bus_sel      = B_OPR;
                  alu_sel      = 0;
                  reg_en[B_AC] = 1;
                 end
        I_MVA  : begin 
                  bus_sel      = opr;
                  alu_sel      = 0;
                  reg_en[B_AC] = 1;
                 end
        I_MVR  : reg_en[opr] = 1;   // one-hot decoding
        I_JMZ  : if (z_ac) pc_next = opr;
        I_JMN  : if (n_ac) pc_next = opr;
        // Default case covers all arithmetic & logic instructions
        default: begin 
                  bus_sel = opr;
                  alu_sel = opc;
                  reg_en[B_AC] = 1'b1;
                end
      endcase
  end

endmodule