module reg_MEMWB (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        flush_MEMWB,

    // Control from MEM
    input  wire        RegWrite_MEM,
    input  wire [1:0]  ResultSrc_MEM,

    // Data from MEM
    input  wire [31:0] ReadData_MEM,//ld 때문에 입력으로 받았지만 현재 사용하지 않음
    input  wire [31:0] ALU_result_MEM,
    input  wire [31:0] PC_MEM,
    input  wire [31:0] PCadd4_MEM,
    input  wire [4:0]  rac_MEM,

    // Outputs towards WB
    output reg         RegWrite_WB,
    output reg  [1:0]  ResultSrc_WB,
    output reg  [31:0] ReadData_WB,//ld 출력이지만 현재 사용하지 않음
    output reg  [31:0] ALU_result_WB,
    output reg  [31:0] PCadd4_WB,
    output reg  [4:0]  rac_WB,
    output reg  [31:0] PC_WB
);

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            RegWrite_WB    <= 1'b0;
            ResultSrc_WB   <= 2'b00;
            ReadData_WB    <= 32'b0;
            ALU_result_WB  <= 32'b0;
            PCadd4_WB      <= 32'b0;
            rac_WB         <= 5'b0;
        end else if (flush_MEMWB) begin
            RegWrite_WB    <= 1'b0;
            ResultSrc_WB   <= 2'b00;
            ReadData_WB    <= 32'b0;
            ALU_result_WB  <= 32'b0;
            PCadd4_WB      <= 32'b0;
            rac_WB         <= 5'b0;
        end else begin
            RegWrite_WB    <= RegWrite_MEM;
            ResultSrc_WB   <= ResultSrc_MEM;
            ReadData_WB    <= ReadData_MEM;
            ALU_result_WB  <= ALU_result_MEM;
            PC_WB          <= PC_MEM;
            PCadd4_WB      <= PCadd4_MEM;
            rac_WB         <= rac_MEM;
        end
    end

endmodule

