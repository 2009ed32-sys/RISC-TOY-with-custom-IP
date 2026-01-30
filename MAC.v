module MAC (
    // 4-bit unsigned operands (0..15)
    input  wire signed[3:0]  a_in,
    input  wire signed[3:0]  b_in,
    input  wire               CLK,
    input  wire               RSTN,
    input  wire               clr, // Sync clear

    // Forwarded systolic streams keep the same width as inputs
    output reg  signed[3:0]  a_out,
    output reg  signed[3:0]  b_out,
    output reg  signed[19:0] result,
    output reg                done,

    input  wire               enable,
    input  wire               update_ready
);

    // -------------------------------------------------
    // Clock gating
    // - Gate only the accumulator update clock (result), since that's the
    //   highest-toggle datapath. a_out/b_out/done keep using CLK to preserve
    //   "done pulses low when idle" semantics.
    // -------------------------------------------------
    wire acc_en  = enable & update_ready;
    wire acc_clk;

    clk_gate u_clk_gate (
        .CLK (CLK),
        .RSTN(RSTN),
        .EN  (acc_en),
        .GCLK(acc_clk)
    );

    // Systolic data forward + done pulse (ungated clock)
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            a_out <= 4'sd0;
            b_out <= 4'sd0;
            done  <= 1'b0;
        end else begin
            // done is a 1-cycle pulse when an accumulation happens
            done <= acc_en;

            if (enable) begin
                a_out <= a_in;
                b_out <= b_in;
            end
        end
    end

    // Accumulator (gated clock)
    // Note: To clear, enable and update_ready must be High so acc_clk toggles.
    always @(posedge acc_clk or negedge RSTN) begin
        if (!RSTN) begin
            result <= 20'sd0;
        end else if (clr) begin
            result <= 20'sd0;
        end else begin
            // Unsigned multiply-accumulate
            result <= result + ($signed(a_in) * $signed(b_in));
        end
    end

endmodule
