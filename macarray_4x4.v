module macarray_4x4 (
    input  wire               CLK,
    input  wire               RSTN,
    input  wire               clr,

    input  wire        [1:0]  enable,
    input  wire               update_ready,

    input  wire signed [3:0]  a_in_row0,
    input  wire signed [3:0]  a_in_row1,
    input  wire signed [3:0]  a_in_row2,
    input  wire signed [3:0]  a_in_row3,

    input  wire signed [3:0]  b_in_col0,
    input  wire signed [3:0]  b_in_col1,
    input  wire signed [3:0]  b_in_col2,
    input  wire signed [3:0]  b_in_col3,

    output wire signed [19:0] C00, C01, C02, C03,
    output wire signed [19:0] C10, C11, C12, C13,
    output wire signed [19:0] C20, C21, C22, C23,
    output wire signed [19:0] C30, C31, C32, C33,

    output wire signed [15:0] a_out
);
    // A horizontal links
    wire signed [3:0] a_0_1, a_0_2, a_0_3;
    wire signed [3:0] a_1_1, a_1_2, a_1_3;
    wire signed [3:0] a_2_1, a_2_2, a_2_3;
    wire signed [3:0] a_3_1, a_3_2, a_3_3;

    // B vertical links
    wire signed [3:0] b_1_0, b_2_0, b_3_0;
    wire signed [3:0] b_1_1, b_2_1, b_3_1;
    wire signed [3:0] b_1_2, b_2_2, b_3_2;
    wire signed [3:0] b_1_3, b_2_3, b_3_3;

    // done wires (optional)
    wire d00, d01, d02, d03;
    wire d10, d11, d12, d13;
    wire d20, d21, d22, d23;
    wire d30, d31, d32, d33;

    assign a_out = {a_in_row3, a_in_row2, a_in_row1, a_in_row0};

    // Row 0
    MAC pe00 (.a_in(a_in_row0), .b_in(b_in_col0), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_0_1), .b_out(b_1_0), .result(C00), .done(d00), .enable(enable[0]), .update_ready(update_ready));
    MAC pe01 (.a_in(a_0_1),     .b_in(b_in_col1), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_0_2), .b_out(b_1_1), .result(C01), .done(d01), .enable(enable[0]), .update_ready(update_ready));
    MAC pe02 (.a_in(a_0_2),     .b_in(b_in_col2), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_0_3), .b_out(b_1_2), .result(C02), .done(d02), .enable(enable[0]), .update_ready(update_ready));
    MAC pe03 (.a_in(a_0_3),     .b_in(b_in_col3), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(/*unused*/), .b_out(b_1_3), .result(C03), .done(d03), .enable(enable[1]), .update_ready(update_ready));

    // Row 1
    MAC pe10 (.a_in(a_in_row1), .b_in(b_1_0), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_1_1), .b_out(b_2_0), .result(C10), .done(d10), .enable(enable[0]), .update_ready(update_ready));
    MAC pe11 (.a_in(a_1_1),     .b_in(b_1_1), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_1_2), .b_out(b_2_1), .result(C11), .done(d11), .enable(enable[0]), .update_ready(update_ready));
    MAC pe12 (.a_in(a_1_2),     .b_in(b_1_2), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_1_3), .b_out(b_2_2), .result(C12), .done(d12), .enable(enable[0]), .update_ready(update_ready));
    MAC pe13 (.a_in(a_1_3),     .b_in(b_1_3), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(/*unused*/), .b_out(b_2_3), .result(C13), .done(d13), .enable(enable[1]), .update_ready(update_ready));

    // Row 2
    MAC pe20 (.a_in(a_in_row2), .b_in(b_2_0), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_2_1), .b_out(b_3_0), .result(C20), .done(d20), .enable(enable[0]), .update_ready(update_ready));
    MAC pe21 (.a_in(a_2_1),     .b_in(b_2_1), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_2_2), .b_out(b_3_1), .result(C21), .done(d21), .enable(enable[0]), .update_ready(update_ready));
    MAC pe22 (.a_in(a_2_2),     .b_in(b_2_2), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_2_3), .b_out(b_3_2), .result(C22), .done(d22), .enable(enable[0]), .update_ready(update_ready));
    MAC pe23 (.a_in(a_2_3),     .b_in(b_2_3), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(/*unused*/), .b_out(b_3_3), .result(C23), .done(d23), .enable(enable[1]), .update_ready(update_ready));

    // Row 3
    MAC pe30 (.a_in(a_in_row3), .b_in(b_3_0), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_3_1), .b_out(/*unused*/), .result(C30), .done(d30), .enable(enable[1]), .update_ready(update_ready));
    MAC pe31 (.a_in(a_3_1),     .b_in(b_3_1), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_3_2), .b_out(/*unused*/), .result(C31), .done(d31), .enable(enable[1]), .update_ready(update_ready));
    MAC pe32 (.a_in(a_3_2),     .b_in(b_3_2), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(a_3_3), .b_out(/*unused*/), .result(C32), .done(d32), .enable(enable[1]), .update_ready(update_ready));
    MAC pe33 (.a_in(a_3_3),     .b_in(b_3_3), .CLK(CLK), .RSTN(RSTN), .clr(clr), .a_out(/*unused*/), .b_out(/*unused*/), .result(C33), .done(d33), .enable(enable[1]), .update_ready(update_ready));

endmodule
