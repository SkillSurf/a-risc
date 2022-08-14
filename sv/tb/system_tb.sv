/*
  Engineer    : Abarajithan G
  Company     : -
  Create Date : 31-July-2022
  Design Name : system_tb
  Description : Testbench to read given assembly file to be executed in the processor
*/

timeunit 1ns/1ps;

module system_tb #(
  NUM_GPR = 8,
  RAM_DEPTH = 256,
  string ALGO = "1_triangular"
);

  logic clk=0, rstn=0, start=0, idle;

  localparam CLK_PERIOD=10;
  initial forever #(CLK_PERIOD/2) clk <= ~clk;

  string file_dir = "D:/arisc/algo/";
  string filename_in_iram  = {file_dir, ALGO, "_in_mcode.txt"};
  string filename_in_dram  = {file_dir, ALGO, "_in_dram.txt"};
  string filename_out_dram = {file_dir, ALGO, "_out_dram.txt"};

  localparam W = $clog2(RAM_DEPTH);

  logic dram_write;
  logic [15:0] iram_dout;
  logic [W-1:0] iram_addr, dram_din, dram_dout, dram_addr;

  mock_ram #(.W_DATA(16), .DEPTH(RAM_DEPTH), .LATENCY(1)) IRAM (
    .clk      (clk), 
    .write_en (1'b0),
    .addr     (iram_addr),
    .din      (16'b0),
    .dout     (iram_dout)
  );

  mock_ram #(.W_DATA(W), .DEPTH(RAM_DEPTH), .LATENCY(1)) DRAM (
    .clk      (clk), 
    .write_en (dram_write),
    .addr     (dram_addr),
    .din      (dram_din),
    .dout     (dram_dout)
  );

  cpu #(.NUM_GPR(NUM_GPR), .W(W)) CPU (.*);

  int fh_iram, fh_in_dram, fh_out_dram, status, addr=0, value;
  string line, opcode_s, rd_s, ra_s, rb_s;
  logic [3:0] opcode, rd, ra, rb;

  initial begin
    @(posedge clk) #1 rstn = 1; // reset

    // Read from file into IRAM
    fh_iram = $fopen(filename_in_iram, "r");

    while (1) begin
      status = $fgets(line, fh_iram);

      // skip empty lines & comment lines
      if (line == "\n" | line.substr(0,0) == "#") continue;

      // extract [opcode, rd, ra, rb] in the following format
      // 0000 0000 0000 0000 
      // (with single space in between), parse them as binary
      opcode_s = line.substr(0,3);
      rd_s = line.substr(5, 8);
      ra_s = line.substr(10,13);
      rb_s = line.substr(15,18);

      opcode = opcode_s.atobin();
      rd = rd_s.atobin();
      ra = ra_s.atobin();
      rb = rb_s.atobin();

      // write into IRAM
      IRAM.ram[addr] = {rb, ra, rd, opcode};
      addr += 1;

      if (opcode == 0) break;
    end
    $fclose(fh_iram);

    // If in_dram file is available, open and load into dram
    fh_in_dram = $fopen(filename_in_dram, "r");
    if (fh_in_dram) begin
      addr = 0;
      while (!$feof(fh_in_dram)) begin
        status = $fgets(line, fh_iram);
        value = line.atobin();
        DRAM.ram[addr] = value;
        addr += 1;
      end
      $fclose(fh_in_dram);
    end

    // Start processing & wait to complete
    @(posedge clk) #1 start = 1;
    @(posedge clk) #1 start = 0;

    wait(idle); // wait for cpu to complete & raise idle
    @(posedge clk) #1

    // Read from DRAM into file
    fh_out_dram = $fopen(filename_out_dram, "w");
    for (addr=0; addr<RAM_DEPTH; addr++) $fdisplay(fh_out_dram, "%d", DRAM.ram[addr]);
    $fclose(fh_out_dram);
    
    $finish();
  end

endmodule