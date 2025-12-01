// dcls_comparator.sv
`timescale 1ns/1ps

// ------------------------------------------------------------------
// InputPort
// - Simple module to register incoming signals (one place to change
//   input width / number of signals).
// - in_signals: unpacked array [NUM_SIGNALS-1:0][DATA_WIDTH-1:0]
// ------------------------------------------------------------------
module InputPort #(
    parameter int NUM_SIGNALS = 8,
    parameter int DATA_WIDTH = 32
) (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] in_signals,
    output logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] out_signals
);
    // register inputs to align and stabilize them
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_signals <= '0;
        end else begin
            out_signals <= in_signals;
        end
    end
endmodule

// ------------------------------------------------------------------
// DelayLine
// - Delays the input vector up to 3 cycles.
// - delay_sel: 2'b00 -> 0 cycles (no delay), 01->1, 10->2, 11->3
// - Generic for NUM_SIGNALS x DATA_WIDTH
// ------------------------------------------------------------------
module DelayLine #(
    parameter int NUM_SIGNALS = 8,
    parameter int DATA_WIDTH  = 32
) (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic [1:0]                    delay_sel,   // 00/01/10/11 => 0/1/2/3 cycles
    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] din, // stage 0 (current)
    output logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] dout
);
    // Implement up to 3-stage shift registers
    logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] stage1, stage2, stage3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= '0;
            stage2 <= '0;
            stage3 <= '0;
        end else begin
            stage1 <= din;
            stage2 <= stage1;
            stage3 <= stage2;
        end
    end

    // multiplexer selecting the correct delay
    always_comb begin
        unique case (delay_sel)
            2'b00: dout = din;       // 0 cycles
            2'b01: dout = stage1;    // 1 cycle
            2'b10: dout = stage2;    // 2 cycles
            2'b11: dout = stage3;    // 3 cycles
            default: dout = din;
        endcase
    end
endmodule

// ------------------------------------------------------------------
// Comparator
// - Compares two arrays of outputs from core0 and core1
// - Produces error (any mismatch) and per-signal mismatch vector
// ------------------------------------------------------------------
module Comparator #(
    parameter int NUM_SIGNALS = 8,
    parameter int DATA_WIDTH  = 32
) (
    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] a,
    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] b,
    output logic                                      any_mismatch,
    output logic [NUM_SIGNALS-1:0]                    mismatch_vector // 1 => that signal differs
);
    integer i;
    always_comb begin
        any_mismatch = 1'b0;
        mismatch_vector = '0;
        for (i = 0; i < NUM_SIGNALS; i++) begin
            mismatch_vector[i] = (a[i] !== b[i]); // use case equality to detect X/Z if needed
            if (mismatch_vector[i]) any_mismatch = 1'b1;
        end
    end
endmodule

// ------------------------------------------------------------------
// Top-level DCLS block
// - Instantiates InputPort, DelayLine, Two core instances (placeholders),
//   and Comparator.
// - Replace `dummy_core` with your actual core module name and ports.
// ------------------------------------------------------------------
module dcls_top #(
    parameter int NUM_SIGNALS = 8,
    parameter int DATA_WIDTH  = 32
) (
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic [1:0]                    delay_sel,  // controls delay for core1
    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] external_in, // incoming stimulus
    output logic                          error,       // asserted when any mismatch
    output logic [NUM_SIGNALS-1:0]        error_vector // per-signal mismatch
);
    // Internal wires
    logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] in_reg;
    logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] core0_in, core1_in;
    logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] core0_out, core1_out;

    // Input registration
    InputPort #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) u_input (
        .clk(clk), .rst_n(rst_n),
        .in_signals(external_in),
        .out_signals(in_reg)
    );

    // Core0 gets the registered inputs directly (no additional delay)
    assign core0_in = in_reg;

    // Core1 input is delayed according to delay_sel
    DelayLine #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) u_delay (
        .clk(clk), .rst_n(rst_n),
        .delay_sel(delay_sel),
        .din(in_reg),
        .dout(core1_in)
    );

    // ------------------------------------------------------------------
    // CORE INSTANCES
    // Replace 'dummy_core' with your real core. The interface below is:
    // module your_core (
    //    input  logic clk,
    //    input  logic rst_n,
    //    input  logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] core_in,
    //    output logic [NUM_SIGNALS-1:0][DATA_WIDTH-1:0] core_out
    // );
    // ------------------------------------------------------------------

    // Placeholder cores (simple pass-through registered)
    dummy_core #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) core0_inst (
        .clk(clk), .rst_n(rst_n),
        .core_in(core0_in),
        .core_out(core0_out)
    );

    dummy_core #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) core1_inst (
        .clk(clk), .rst_n(rst_n),
        .core_in(core1_in),
        .core_out(core1_out)
    );

    // Comparator
    Comparator #(.NUM_SIGNALS(NUM_SIGNALS), .DATA_WIDTH(DATA_WIDTH)) u_cmp (
        .a(core0_out),
        .b(core1_out),
        .any_mismatch(error),
        .mismatch_vector(error_vector)
    );

endmodule
