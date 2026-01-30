
module clk_gate (
    input  wire CLK,
    input  wire RSTN,
    input  wire EN,
    output wire GCLK
);
    reg en_latched;

    always @(negedge CLK or negedge RSTN) begin
        if (!RSTN)
            en_latched <= 1'b0;
        else
            en_latched <= EN;
    end

    assign GCLK = CLK & en_latched;
endmodule


