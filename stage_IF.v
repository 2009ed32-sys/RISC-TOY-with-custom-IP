module stage_IF (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        branch_ID,  
	 
	 input  wire        stall_PC,//stall

    // ID stage에서 온 Jump 정보 (Jump는 ID에서 처리)
    input  wire [1:0]  PCSrc_ID,
    input  wire [31:0] PCTarget_ID,
    
    // EX stage에서 온 Branch 정보 (Branch는 EX에서 처리)
    input  wire [1:0]  PCSrc_EX,     
    input  wire [31:0] PCTarget_EX,

    // IF stage 출력
    output wire [31:0] PC_IF,
    output wire [31:0] PCadd4_IF,

    // Instruction Memory 인터페이스
    output wire        IREQ,
    output wire [29:0] IADDR // Fixed: Back to 30 bits to match RISC_TOY.v
);

    reg [31:0] PC;
    reg [31:0] PC_next;
    reg        PCWrite_IF;

    // -------------------------
    // 1. Next PC 결정 로직
    // -------------------------
    // Priority: ID stage (Jump) > EX stage (Branch) > Sequential
    /*always @(*) begin
	 
        if (PCSrc_ID != 2'b00) begin
            PC_next = PCTarget_ID; // Jump (ID stage)
        end else if (PCSrc_EX != 2'b00) begin
            PC_next = PCTarget_EX; // Branch (EX stage)
        end else begin
            PC_next = PC + 32'd4;  // Sequential
        end
    end*/
	 always @(*) begin
        // [핵심 수정] Stall 신호가 들어오면, PC는 절대 증가하지 않고 현재 값 유지!
        if (stall_PC) begin
            PC_next = PC; 
        end
        // Jump (ID stage)
        else if (PCSrc_ID != 2'b00) begin
            PC_next = PCTarget_ID;
        end 
        // Branch (EX stage)
        else if (PCSrc_EX != 2'b00) begin
            PC_next = PCTarget_EX;
        end 
        // Sequential (기본)
        else begin
            PC_next = PC + 32'd4;
        end
    end
    // PCWrite Control Logic
    // Combinational: PC should always update except during reset
    always @(*) begin
        if (!RSTN) begin
             PCWrite_IF = 1'b0;
		  end else if (stall_PC) begin  // <--- [추가] Stall이면 쓰기 금지
             PCWrite_IF = 1'b0;
        end else begin
             PCWrite_IF = 1'b1; // Always update PC (Flush handles incorrect instructions)
        end
    end

    // -------------------------
    // 2. PC 레지스터
    // -------------------------
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            PC <= 32'b0;
        end else if (PCWrite_IF) begin
            PC <= PC_next;
        end 
    end

    assign PC_IF = PC;

    // -------------------------
    // 3. 출력
    // -------------------------        
    assign PCadd4_IF = PC+32'd4; 

    assign IREQ = (RSTN) ? 1'b1 : 1'b0;     
    
    // Fix: Match port width [29:0]
    assign IADDR = PC[29:0]; 
    
endmodule
