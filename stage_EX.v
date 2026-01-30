// stage_EX.v (수정 예시)
module stage_EX (
    // 포워딩 관련 입력
    input  wire [31:0] RD1_EX,
    input  wire [31:0] RD2_EX,
    input  wire [31:0] Result_WB,
    input  wire [31:0] ALU_result_MEM,
    input  wire [1:0]  ForwardA,
    input  wire [1:0]  ForwardB,   
    input  wire [2:0]  BR_cond_ID,

    // ID/EX 파이프레지스터에서 넘어온 제어/데이터
    input  wire [1:0]  ALUSrc_EX,        // 00: RD2, 01: imm, 10: imm(특수)
    input  wire [1:0]  LoadStoreSrc_EX,  // 00: 일반, 01: PC-relative, 10: IP 등
    input  wire [3:0]  ALUControl_EX,
    input  wire [31:0] immExtend_EX,
    input  wire [31:0] PC_EX,
    input  wire [5:0]  shift_amount_EX,
    input  wire        Branch_EX,        // "이미 조건까지 체크된" 브랜치 수행 여부
    input  wire        Jump_EX,
    input  wire        rb1111check_EX,
    input  wire [2:0]  BR_cond_EX, // Added

    // EX stage 출력
    output wire [31:0] RD1_EX_a,         // 포워딩 반영된 A
    output wire [31:0] RD2_EX_a,         // 포워딩 반영된 B (Store 데이터용)
    output wire [31:0] ALU_result_EX,
    output wire [31:0] PCTarget_EX,
    output wire [1:0]  PCSrc_EX          // 00: PC+4, 01: PCTarget, 그 외: 00
);

    // -------------------------
    // 1. 포워딩 MUX
    // -------------------------
    reg [31:0] RD1_fwd;
    reg [31:0] RD2_fwd;

    always @(*) begin
        // ForwardA: 00(ID/EX), 01(WB), 10(MEM)
        case (ForwardA)
            2'b00: RD1_fwd = RD1_EX;
            2'b01: RD1_fwd = Result_WB;
            2'b10: RD1_fwd = ALU_result_MEM;
            2'b11: RD1_fwd = Result_WB;
            default: RD1_fwd = RD1_EX;
        endcase
    end

    always @(*) begin
        // ForwardB: 00(ID/EX), 01(WB), 10(MEM)
        case (ForwardB)
            2'b00: RD2_fwd = RD2_EX;
            2'b01: RD2_fwd = Result_WB;
            2'b10: RD2_fwd = ALU_result_MEM;
            default: RD2_fwd = RD2_EX;
        endcase
    end

    assign RD1_EX_a = RD1_fwd; // 디버그용 / EX-stage A operand
    assign RD2_EX_a = RD2_fwd; // Store 데이터용 (MEM stage로 전달)

    // -------------------------
    // 2. ALU 입력 선택
    //    - LoadStoreSrc_EX로 PC-relative 처리
    // -------------------------
    reg [31:0] ALU_in_A;
    reg [31:0] ALU_in_B;

    always @(*) begin
        // A 입력 선택
        case (LoadStoreSrc_EX)
            2'b01: ALU_in_A = PC_EX;    // PC-relative Load/Store/J-type
            2'b10: ALU_in_A = 32'b0;
            default: ALU_in_A = (rb1111check_EX) ? 32'b0 : RD1_fwd; // 기본은 RD1
        endcase

        // B 입력 선택
        case (ALUSrc_EX)
            2'b00: ALU_in_B = RD2_fwd;      // R-type, Branch 비교 등
            2'b01: ALU_in_B = immExtend_EX; // I-type, 일반 Load/Store
            2'b10: ALU_in_B = immExtend_EX + PC_EX; // 특수 주소 계산/즉시값
            2'b11: ALU_in_B = immExtend_EX + PC_EX + 32'd4; // JL
            default: ALU_in_B = RD2_fwd;
        endcase
    end
	 
	 wire [4:0] final_shamt = (shift_amount_EX[5]) ? ALU_in_B[4:0] : shift_amount_EX[4:0];

    // -------------------------
    // 3. ALU 연산
    // -------------------------
    reg [31:0] alu_out;
    reg        zero_flag; // Changed name from zero_flag to cond_met


    always @(*) begin
        case (ALUControl_EX)
            4'b0000: alu_out = ALU_in_A + ALU_in_B;               // ADD
            4'b0001: alu_out = ALU_in_A - ALU_in_B;               // SUB
            4'b0010: alu_out = ALU_in_A & ALU_in_B;               // AND
            4'b0011: alu_out = ALU_in_A | ALU_in_B;               // OR
            4'b0100: alu_out = ALU_in_A ^ ALU_in_B;               // XOR
            4'b0101: alu_out = ~ALU_in_A;                         // NOT
            4'b0110: alu_out = -ALU_in_A;                         // NEG
            4'b0111: alu_out = ALU_in_A <<  final_shamt;      // SHL
            4'b1000: alu_out = ALU_in_A >>  final_shamt;      // LSR
            4'b1001: alu_out = $signed(ALU_in_A) >>> final_shamt; // ASR
            4'b1010: alu_out = (ALU_in_A >> final_shamt) | (ALU_in_A << (32 - final_shamt));   // ROR
            4'b1011: alu_out = ALU_in_B;                          // MOV / MOVI / LDIP/STIP, BR/BRL (Pass condition value), jl
            4'b1111: alu_out = 32'b0;                        // NOP (Flush)
            default: alu_out = 32'b0;
        endcase

        // Condition Check Logic (Zero, Nonzero, Plus, Minus)
        // alu_out should contain the value to test (from R[rc])
        case (BR_cond_EX)
            3'b000: zero_flag = 1'b0; // never
            3'b001: zero_flag = 1'b1; // always
            3'b010: zero_flag = (alu_out == 32'b0); // zero
            3'b011: zero_flag = (alu_out != 32'b0); // nonzero
            3'b100: zero_flag = ($signed(alu_out) >= 0); // plus
            3'b101: zero_flag = ($signed(alu_out) < 0);  // minus
            default: zero_flag = 1'b0;
        endcase
    end

    assign ALU_result_EX = alu_out;  // ALU 연산 결과 (PC-relative일 때도 PC_EX + immExtend_EX)

    // -------------------------
    // 4. Branch 타겟 및 PCSrc 생성
    // -------------------------
    // Note: Jump는 ID stage에서 처리됨
    // Branch만 EX stage에서 처리: PC = R[rb] (Register Indirect)
    assign PCTarget_EX = (Branch_EX & zero_flag) ? ALU_in_A : 32'b0; // BR (Register Indirect)

    wire branch_taken;
    assign branch_taken = (Branch_EX & zero_flag); // Branch only (Jump는 ID에서 처리)

    assign PCSrc_EX = (branch_taken) ? 2'b01 : 2'b00;

endmodule
