module stage_WB (
    // Inputs
    input  wire [1:0]  ResultSrc_WB,
    input  wire [31:0] ALU_result_WB,
    input  wire [31:0] ReadData_MEM,
    input  wire [31:0] PCadd4_WB,
    input  wire [31:0] PC_WB,  // Added for JL/BRL return address

    // Outputs
    output reg [31:0] Result_WB
);

    always @(*) begin
        case (ResultSrc_WB)
            2'b00: Result_WB = ALU_result_WB;
            2'b01: Result_WB = ReadData_MEM;
            2'b10: Result_WB = PC_WB;
            2'b11: Result_WB = PC_WB+32'd4;
            default: Result_WB = 32'b0;
        endcase
    end

endmodule
