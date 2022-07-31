timeunit 1ns/1ps;

module system_tb;

  logic clk = 0, rstn=0, start=0, idle;

  localparam CLK_PERIOD =10;
  initial forever #(CLK_PERIOD/2) clk <= ~clk;

  localparam NUM_GPR = 8;
  string filename_machine_code = "D:/arisc/txt/input/test.txt";
  string filename_output = "D:/arisc/txt/output/test.txt";

  logic iram_write, iram_write_mux, iram_write_tb, dram_write;
  logic [15:0] iram_din=0, iram_dout;
  logic [7 :0] iram_addr, dram_din, dram_dout, dram_addr;

  mock_ram #(.W_DATA(16), .DEPTH(256), .LATENCY(1)) IRAM (
    .clk      (clk), 
    .write_en (iram_write),
    .addr     (iram_addr),
    .din      (iram_din),
    .dout     (iram_dout)
  );

  mock_ram #(.W_DATA(8), .DEPTH(256), .LATENCY(1)) DRAM (
    .clk      (clk), 
    .write_en (dram_write),
    .addr     (dram_addr),
    .din      (dram_din),
    .dout     (dram_dout)
  );

  cpu #(.NUM_GPR(NUM_GPR)) CPU (.*);

  int fi, fo, status, i=0;
  string line, opcode_s, operand_s;
  logic [7:0] opcode, operand;

  initial begin
    @(posedge clk); #1
    rstn = 1;

    fi = $fopen(filename_machine_code, "r");

    while (1) begin
      status = $fgets(line, fi);
      opcode_s = line.substr(0,3);
      operand_s = line.substr(6,9);
      opcode = opcode_s.atobin();
      operand = operand_s.atobin();

      IRAM.ram[i] = {operand, opcode};
      i += 1;

      if (opcode == 8'b0) break;
    end
    $fclose(fi);

    @(posedge clk); #1
    start = 1;
    @(posedge clk); #1
    start = 0;

    wait(idle);
    @(posedge clk); #1

    fo = $fopen(filename_output, "w");
    for (int i=0; i<256; i++) $fdisplay(fo, "%d", DRAM.ram[i]);
    $fclose(fo);
  end

endmodule