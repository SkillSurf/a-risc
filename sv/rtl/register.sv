timeunit 1ns/1ps;

module register #(
  parameter WIDTH = 8,
            RESET_VALUE = 0
)(
  input  logic clk, rstn, en,
  input  logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);

  always_ff @(posedge clk or negedge rstn)
    if      (~rstn) out <= RESET_VALUE;
    else if (en)    out <= in;
  
endmodule