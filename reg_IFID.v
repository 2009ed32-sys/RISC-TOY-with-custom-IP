module reg_IFID (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        stall_IFID,
    input  wire        flush_IFID,
    input  wire [31:0] instruction_IF,
    input  wire [31:0] PC_IF,
    input  wire [31:0] PCadd4_IF,

    output wire  [31:0] instruction_ID,
    output reg  [31:0] PC_ID,
    output reg  [31:0] PCadd4_ID
);
		
	 // 조합논리로 flush 처리: flush_IFID가 1이면 NOP, 아니면 instruction_IF
	 // RSTN이 0이면 초기화 중이므로 NOP 출력 (초기화 보호)
	 assign instruction_ID = (!RSTN || flush_IFID) ? 32'hF8000000 : instruction_IF;    
		
    
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            PC_ID          <= 32'b0;
            PCadd4_ID      <= 32'b0;
        end else if (flush_IFID) begin
            PC_ID          <= 32'b0;
            PCadd4_ID      <= 32'b0;
        end else if (!stall_IFID) begin
            PC_ID          <= PC_IF;
            PCadd4_ID      <= PCadd4_IF;
        end 
    end

endmodule
