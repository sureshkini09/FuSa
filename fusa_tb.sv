

// tb_dcls.sv
`timescale 1ns/1ps
module tb_dcls;
    parameter int NUM_SIGNALS = 4;
    parameter int DATA_WIDTH  = 8;
    logic clk;
    logic rst_n;
    logic [1:0] delay_sel;
    logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] external_in;
    logic error;
    logic [NUM_SIGNALS-1:0] error_vector;

    // instantiate DUT
    dcls_top #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .delay_sel(delay_sel),
        .external_in(external_in),
        .error(error),
        .error_vector(error_vector)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz-ish (10ns period)

    initial begin
        rst_n = 0;
        delay_sel = 2'b00;
        external_in = '0;
        #20;
        rst_n = 1;

        // Case A: no delay, both cores get same signals at same time => no error if cores deterministic
        delay_sel = 2'b00;
        external_in[0] = 8'hA5;
        external_in[1] = 8'h11;
        external_in[2] = 8'h22;
        external_in[3] = 8'h33;
        #30;
        $display("Time %0t: delay_sel=%b error=%b vect=%b", $time, delay_sel, error, error_vector);

        // Case B: set 2-cycle delay and change input at t=...
        delay_sel = 2'b10; // 2-cycle delay to core1
        // change signal to create mismatch scenario -- change input for only one cycle
        external_in[1] = 8'h99; // change a single signal
        #10;
        // restore to previous value to create transient mismatch between core0 and delayed core1
        external_in[1] = 8'h11;
        #80;
        $display("Time %0t: delay_sel=%b error=%b vect=%b", $time, delay_sel, error, error_vector);

        $finish;
    end
endmodule
