module reg_EXMEM (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        stall_EXMEM,
    input  wire        flush_EXMEM,

    // Control signals from EX
    input  wire        RegWrite_EX,
    input  wire [2:0]  MemRW_EX,
    input  wire [1:0]  ResultSrc_EX,

    // Data from EX
    input  wire [31:0] PC_EX,
    input  wire [31:0] PCadd4_EX,
    input  wire [31:0] ALU_result_EX,
    input  wire [31:0] RD2_EX,
    input  wire [4:0]  rac_EX,

    // Outputs towards MEM
    output reg         RegWrite_MEM,
    output reg  [2:0]  MemRW_MEM,
    output reg  [1:0]  ResultSrc_MEM,

    output reg  [31:0] PC_MEM,
    output reg  [31:0] PCadd4_MEM,
    output reg  [31:0] ALU_result_MEM,
    output reg  [31:0] RD2_MEM,
    output reg  [4:0]  rac_MEM
);

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            RegWrite_MEM     <= 1'b0;
            MemRW_MEM        <= 3'b000;
            ResultSrc_MEM    <= 2'b00;
            PC_MEM           <= 32'b0;
            PCadd4_MEM       <= 32'b0;
            ALU_result_MEM   <= 32'b0;
            RD2_MEM          <= 32'b0;
            rac_MEM          <= 5'b0;
        end else if (flush_EXMEM) begin
            RegWrite_MEM     <= 1'b0;
            MemRW_MEM        <= 3'b000;
            ResultSrc_MEM    <= 2'b00;
            PC_MEM           <= 32'b0;
            PCadd4_MEM       <= 32'b0;
            ALU_result_MEM   <= 32'b0;
            RD2_MEM          <= 32'b0;
            rac_MEM          <= 5'b0;
        end else if (!stall_EXMEM) begin
            RegWrite_MEM     <= RegWrite_EX;
            MemRW_MEM        <= MemRW_EX;
            ResultSrc_MEM    <= ResultSrc_EX;
            PC_MEM           <= PC_EX;
            PCadd4_MEM       <= PCadd4_EX;
            ALU_result_MEM   <= ALU_result_EX;
            RD2_MEM          <= RD2_EX;
            rac_MEM          <= rac_EX;
        end
    end

endmodule

