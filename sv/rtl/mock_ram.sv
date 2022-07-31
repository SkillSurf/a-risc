timeunit 1ns/1ps;

module mock_ram #(
  parameter  W_DATA = 8,
             DEPTH = 256,
             LATENCY = 1,
  localparam W_ADDR = $clog2(DEPTH)
)(
  input  logic clk, write_en,
  input  logic [W_ADDR-1:0] addr,
  input  logic [W_DATA-1:0] din,
  output logic [W_DATA-1:0] dout
);

  logic [W_DATA-1:0] ram [DEPTH];

  always_ff @(posedge clk)
    if (write_en) ram[addr] <= din;

  wire [W_DATA-1:0] ram_out = ram[addr];

  // Delay the ram_out through a chain of registers

  wire [W_DATA-1:0] delay [LATENCY:0];
  assign delay[0] = ram_out;

  for (genvar i=0; i<LATENCY; i++)
    register #(W_DATA,0) DELAY (clk, 1'b1, 1'b1, delay[i], delay[i+1]);

  assign dout = delay[LATENCY];

endmodule