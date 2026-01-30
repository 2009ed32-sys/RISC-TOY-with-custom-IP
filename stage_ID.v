module stage_ID (
    input  wire [31:0] instruction_ID,
    input  wire [31:0] RD1,
    input  wire [31:0] RD2,
    input  wire [31:0] PC_ID, // Added for Jump processing

    output wire         RegWrite_ID,
    output wire  [2:0]  MemRW_ID,
    output wire  [1:0]  ALUSrc_ID,
    output wire  [3:0]  ALUControl_ID,
    output wire         Branch_ID,
    output wire         Jump_ID,
    output wire  [1:0]  ResultSrc_ID,
    output wire         rb1111check_ID,
    output wire  [1:0]  LoadStoreSrc_ID,
    output wire [5:0]   shift_amount_ID,

    output reg  [4:0]  ra, // Register File Read Address 1
    output reg  [4:0]  rb, // Register File Read Address 2
    output wire [4:0]  rac_ID, // Register File Write Address
    output wire [2:0]  BR_cond_ID, // Branch Condition Code
    output wire [31:0] RD1_ID,
    output wire [31:0] RD2_ID,
    output reg  [31:0] immExtend_ID,
    
    // Jump processing outputs (ID stage)
    output wire [31:0] PCTarget_ID, // Jump target address
    output wire [1:0]  PCSrc_ID     // 00: PC+4, 01: PCTarget, 그 외: 00
);

    // --- Field Extraction ---
    wire [4:0] opcode_field = instruction_ID[31:27];
    wire [4:0] ra_field     = instruction_ID[26:22];
    wire [4:0] rb_field     = instruction_ID[21:17];
    wire [4:0] rc_field     = instruction_ID[16:12];
    wire [4:0] shamt_field  = instruction_ID[4:0];
    wire [2:0] br_cond_field = instruction_ID[2:0];
    
    wire [16:0] imm17       = instruction_ID[16:0];
    wire [21:0] imm22       = instruction_ID[21:0];
    wire [2:0]  cond_field  = instruction_ID[2:0];

    // --- CONTROL UNIT INSTANTIATION ---
    CONTROL control_unit (
        .opcode         (opcode_field),
        .rb             (rb_field),
        
        .RegWrite_ID    (RegWrite_ID),
        .MemRW_ID       (MemRW_ID),
        .ALUSrc_ID      (ALUSrc_ID),
        .ALUControl_ID  (ALUControl_ID),
        .Branch_ID      (Branch_ID),
        .Jump_ID        (Jump_ID),
        .ResultSrc_ID   (ResultSrc_ID),
        .rb1111check_ID (rb1111check_ID),
        .LoadStoreSrc_ID(LoadStoreSrc_ID)
        //.BR_cond_ID     (br_cond_ID)
    );

    // --- Basic Assignments ---
    assign shift_amount_ID = instruction_ID[5:0];
    assign RD1_ID = RD1;
    assign RD2_ID = RD2;
    
    // --- Branch Condition Extraction ---
    assign BR_cond_ID = cond_field;

    // --- Write Address Logic ---
    assign rac_ID = ra_field;

    // --- Register Read Address Muxing ---
    always @(*) begin
        // Default Setting
        ra = rb_field;
        rb = rc_field;

        case (opcode_field)
            // 1. Store Instruction (ST)
            5'b10011: begin 
                ra = rb_field; 
                rb = ra_field; 
            end
            
            // 2. PC-Relative Store (STR)
            5'b10100: begin 
                ra = 5'b00000; 
                rb = ra_field; 
            end
				
				5'b00011, 5'b00100: begin
                ra = rc_field; // rb 대신 rc를 읽어야 함
                rb = 5'b00000; // 사용 안 함
            end
            
            default: begin
                // Keep default
            end
        endcase
    end

    // --- Immediate Extension Logic (Data Path Logic) ---
    // Note: Control signals are now from CONTROL module, but extension values are calculated here
    always @(*) begin
        // Default Immediate: Sign Extension 17-bit
        immExtend_ID = 32'b0;

        case (opcode_field)
            // --- J-type Ops ---
            5'b01111: begin // J
                immExtend_ID = {{10{imm22[21]}}, imm22}; 
            end
            5'b10000: begin // JL
                immExtend_ID = {{10{imm22[21]}}, imm22}; 
            end

            // --- Memory Ops ---
            5'b10011: begin // ST
                // if (rb==31) zeroExt(imm17), else signExt(imm17)
                if (rb_field == 5'b11111) begin
                    immExtend_ID = {15'b0, imm17}; // zeroExt
                end else begin
                    immExtend_ID = {{15{imm17[16]}}, imm17}; // signExt
                end
            end
            5'b10100: begin // STR
                immExtend_ID = {{10{imm22[21]}}, imm22}; 
            end
            5'b10101: begin // LD
                // if (rb==31) zeroExt(imm17), else signExt(imm17)
                if (rb_field == 5'b11111) begin
                    immExtend_ID = {15'b0, imm17}; // zeroExt
                end else begin
                    immExtend_ID = {{15{imm17[16]}}, imm17}; // signExt
                end
            end
            5'b10110: begin // LDR
                immExtend_ID = {{10{imm22[21]}}, imm22}; 
            end

            // --- IP Ops ---
            5'b10111: begin // LDIP
                immExtend_ID = {10'b0, imm22}; 
            end
            5'b11000: begin // STIP
                immExtend_ID = {10'b0, imm22}; 
            end
            default: begin
                // Default: Sign Extension 17-bit (for MOVI, ADDI, ANDI, ORI, etc.)
                immExtend_ID = {{15{imm17[16]}}, imm17};
            end
        endcase
    end

    // -------------------------
    // Jump Processing (ID stage)
    // -------------------------
    // Jump is PC-relative: PC_ID + immExtend_ID
	assign PCTarget_ID = (Jump_ID) ? (PC_ID + 32'd4 + immExtend_ID) : 32'b0;
    assign PCSrc_ID    = (Jump_ID) ? 2'b01 : 2'b00; // Jump always taken

endmodule
