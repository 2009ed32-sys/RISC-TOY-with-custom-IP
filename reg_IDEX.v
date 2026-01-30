module reg_IDEX (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        stall_IDEX,
    input  wire        flush_IDEX,

    // Control signals from ID
    input  wire        RegWrite_ID,
    input  wire [2:0]  MemRW_ID,
    input  wire [1:0]  ALUSrc_ID,
    input  wire [3:0]  ALUControl_ID,
    input  wire        Branch_ID,
    input  wire        Jump_ID,
    input  wire [1:0]  ResultSrc_ID,
    input  wire        rb1111check_ID,
    input  wire [1:0]  LoadStoreSrc_ID,
    input  wire [5:0]  shift_amount_ID,
    input  wire [2:0]  BR_cond_ID,

    // Data from ID
    input  wire [31:0] PC_ID,
    input  wire [31:0] RD1_ID,
    input  wire [31:0] RD2_ID,
    input  wire [31:0] immExtend_ID,
    input  wire [4:0]  ra_ID,
    input  wire [4:0]  rb_ID,
    input  wire [4:0]  rac_ID,

    // Outputs towards EX
    output reg         RegWrite_EX,
    output reg  [2:0]  MemRW_EX,
    output reg  [1:0]  ALUSrc_EX,
    output reg  [3:0]  ALUControl_EX,
    output reg         Branch_EX,
    output reg         Jump_EX,
    output reg  [1:0]  ResultSrc_EX,
    output reg         rb1111check_EX,
    output reg  [1:0]  LoadStoreSrc_EX,
    output reg  [5:0]  shift_amount_EX,
    output reg  [2:0]  BR_cond_EX,
    output reg  [31:0] PC_EX,
    output reg  [31:0] RD1_EX,
    output reg  [31:0] RD2_EX,
    output reg  [31:0] immExtend_EX,
    output reg  [4:0]  ra_EX,
    output reg  [4:0]  rb_EX,
    output reg  [4:0]  rac_EX
);

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            RegWrite_EX      <= 1'b0;
            MemRW_EX         <= 3'b000;
            ALUSrc_EX        <= 2'b00;
            ALUControl_EX    <= 4'b0000;
            Branch_EX        <= 1'b0;
            Jump_EX          <= 1'b0;
            ResultSrc_EX     <= 2'b00;
            rb1111check_EX   <= 1'b0;
            LoadStoreSrc_EX  <= 2'b00;
            shift_amount_EX  <= 6'b0;
            BR_cond_EX       <= 3'b0;
            PC_EX            <= 32'b0;
            RD1_EX           <= 32'b0;
            RD2_EX           <= 32'b0;
            immExtend_EX     <= 32'b0;
            ra_EX            <= 5'b0;
            rb_EX            <= 5'b0;
            rac_EX           <= 5'b0;
        end else if (flush_IDEX) begin
            RegWrite_EX      <= 1'b0;
            MemRW_EX         <= 3'b000;
            ALUSrc_EX        <= 2'b00;
            ALUControl_EX    <= 4'b1111; // Safe NOP
            Branch_EX        <= 1'b0;
            Jump_EX          <= 1'b0;
            ResultSrc_EX     <= 2'b00;
            rb1111check_EX   <= 1'b0;
            LoadStoreSrc_EX  <= 2'b00;
            shift_amount_EX  <= 5'b0;
            BR_cond_EX       <= 3'b0;
            PC_EX            <= 32'b0;
            RD1_EX           <= 32'b0;
            RD2_EX           <= 32'b0;
            immExtend_EX     <= 32'b0;
            ra_EX            <= 5'b0;
            rb_EX            <= 5'b0;
            rac_EX           <= 5'b0;
        end else if (!stall_IDEX) begin
            RegWrite_EX      <= RegWrite_ID;
            MemRW_EX         <= MemRW_ID;
            ALUSrc_EX        <= ALUSrc_ID;
            ALUControl_EX    <= ALUControl_ID;
            Branch_EX        <= Branch_ID;
            Jump_EX          <= Jump_ID;
            ResultSrc_EX     <= ResultSrc_ID;
            rb1111check_EX   <= rb1111check_ID;
            LoadStoreSrc_EX  <= LoadStoreSrc_ID;
            shift_amount_EX  <= shift_amount_ID;
            BR_cond_EX       <= BR_cond_ID;
            PC_EX            <= PC_ID;
            RD1_EX           <= RD1_ID;
            RD2_EX           <= RD2_ID;
            immExtend_EX     <= immExtend_ID;
            ra_EX            <= ra_ID;
            rb_EX            <= rb_ID;
            rac_EX           <= rac_ID;
        end
    end

endmodule

