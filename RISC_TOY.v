/*****************************************
    
    Team 14: 
        2020104194    Nam InSu
        2023104146    GuminJu
		  2021104344    Ju Hwansu
*****************************************/

// You are able to add additional modules and instantiate in RISC_TOY.

////////////////////////////////////
//  TOP MODULE
////////////////////////////////////
module RISC_TOY (
    input      wire              CLK,
    input      wire              RSTN,
    output     wire              IREQ,
    output     wire    [29:0]    IADDR,
    input      wire    [31:0]    INSTR,
    output     wire              DREQ,
    output     wire    [1:0]     DRW,
    output     wire    [29:0]    DADDR,
    output     wire    [31:0]    DWDATA,
    output     wire    [31:0]    CONSIG,
    input      wire    [31:0]    DRDATA
);

    //-------------------------------------------------------------------------
    // Program Counter / IF Stage
    //-------------------------------------------------------------------------
    wire [31:0] PC_IF;
    wire [31:0] PCadd4_IF;
    wire [31:0] instruction_IF = INSTR;

    // ID stage Jump signals
    wire [31:0] PCTarget_ID;
    wire [1:0]  PCSrc_ID;
    
    // EX stage Branch signals
    wire [31:0] PCTarget_EX;
    wire [1:0]  PCSrc_EX;
    
    // Forward declaration for Branch Detection
    wire Branch_ID;
    wire Jump_ID;
    wire stall_branch_signal = (Branch_ID || Jump_ID);
    
    wire stall_pipeline; // HAZARD_UNIT signal
    
    stage_IF stage_if_inst (
        .CLK(CLK),
        .RSTN(RSTN),
        .branch_ID(stall_branch_signal),
        .stall_PC(stall_pipeline),        // Connected
        .PCSrc_ID(PCSrc_ID),              // Jump (ID stage)
        .PCTarget_ID(PCTarget_ID),        // Jump (ID stage)
        .PCTarget_EX(PCTarget_EX),        // Branch (EX stage)
        .PCSrc_EX(PCSrc_EX),              // Branch (EX stage)
        //.PCWrite_IF(PCWrite_IF), 
        .IREQ(IREQ),
        .IADDR(IADDR),
        .PC_IF(PC_IF),
        .PCadd4_IF(PCadd4_IF)
    );

    //-------------------------------------------------------------------------
    // Pipeline control
    //-------------------------------------------------------------------------
    wire stall_IFID  = stall_pipeline;
    wire stall_IDEX  = 1'b0;
    wire stall_EXMEM = 1'b0;

    // PCSrc_ID (Jump) delayed for flush -- Delay Slot 다음 명령어 flush용
    reg PCSrc_ID_delayed;
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) 
            PCSrc_ID_delayed <= 1'b0;
        else 
            PCSrc_ID_delayed <= (PCSrc_ID != 2'b00); 
    end
    
    // PCSrc_EX (Branch) delayed for flush -- REMOVED for Delay Slot
    // reg PCSrc_EX_delayed;
    // always @(posedge CLK or negedge RSTN) begin
    //    if (!RSTN) PCSrc_EX_delayed <= 1'b0;
    //    else PCSrc_EX_delayed <= (PCSrc_EX != 2'b00); 
    // end

    // Flush logic
    // J(ID): Delay Slot은 실행되지만, Delay Slot 다음 명령어는 flush해야 함
    // BR(EX): Flush IF/ID only (Wrong instruction in IF is killed, Delay slot in ID executes)
    // RSTN이 0이면 flush 안 함 (초기화 중에는 flush 금지)
    assign flush_IFID  = (RSTN) ? ((PCSrc_EX != 2'b00) || PCSrc_ID_delayed) : 1'b0;    
    
    // Stall logic added to flush_IDEX
    // BR: No flush for ID/EX (Delay slot must proceed to EX)
    // Hazard: Flush ID/EX to insert bubble
    assign flush_IDEX  = stall_pipeline;
    
    wire flush_EXMEM = 1'b0;
    wire flush_MEMWB = 1'b0;

    //-------------------------------------------------------------------------
    // IF/ID Pipeline Register
    //-------------------------------------------------------------------------
    wire [31:0] instruction_ID;
    wire [31:0] PC_ID;
    wire [31:0] PCadd4_ID;

    reg_IFID reg_ifid (
        .CLK(CLK),
        .RSTN(RSTN),
        .stall_IFID(stall_IFID),
        .flush_IFID(flush_IFID),
        .instruction_IF(instruction_IF),
        .PC_IF(PC_IF),
        .PCadd4_IF(PCadd4_IF),
        .instruction_ID(instruction_ID),
        .PC_ID(PC_ID),
        .PCadd4_ID(PCadd4_ID)
    );

    //-------------------------------------------------------------------------
    // Register File
    //-------------------------------------------------------------------------
    wire        RegWrite_WB;
    wire [4:0]  rac_WB;
    wire [31:0] Result_WB;
    wire [31:0] RD1_RF;
    wire [31:0] RD2_RF;

    // Register source selections from ID stage
    wire [4:0]  ra_ID;
    wire [4:0]  rb_ID;

    REGFILE #(.AW(5), .ENTRY(32)) RegFile (
        .CLK   (CLK),
        .RSTN  (RSTN),
        .WEN   (~RegWrite_WB),
        .WA    (rac_WB),
        .DI    (Result_WB),
        .RA0   (ra_ID),
        .RA1   (rb_ID),
        .DOUT0 (RD1_RF),
        .DOUT1 (RD2_RF),
        .CONSIG(CONSIG)
    );

    //-------------------------------------------------------------------------
    // ID Stage
    //-------------------------------------------------------------------------
    wire        RegWrite_ID;
    wire [2:0]  MemRW_ID;
    wire [1:0]  ALUSrc_ID;
    wire [3:0]  ALUControl_ID;
    // Branch_ID, Jump_ID declared above
    wire [1:0]  ResultSrc_ID;
    wire        rb1111check_ID;
    wire [1:0]  LoadStoreSrc_ID;
    wire [5:0]  shift_amount_ID;
    wire [4:0]  rac_ID;
    wire [2:0]  BR_cond_ID; // Added
    wire [31:0] RD1_ID;
    wire [31:0] RD2_ID;
    wire [31:0] immExtend_ID;

    // --- ID Stage Forwarding Logic (Solve WB-ID Hazard) MUX ---
    wire [31:0] RD1_Final = (RegWrite_WB && (rac_WB != 5'b0) && (rac_WB == ra_ID)) ? Result_WB : RD1_RF;
    wire [31:0] RD2_Final = (RegWrite_WB && (rac_WB != 5'b0) && (rac_WB == rb_ID)) ? Result_WB : RD2_RF;

    stage_ID stage_id (
        .instruction_ID(instruction_ID),
        .RD1(RD1_Final), // Forwarding applied
        .RD2(RD2_Final), // Forwarding applied
        .PC_ID(PC_ID),   // Added for Jump processing
        .RegWrite_ID(RegWrite_ID),
        .MemRW_ID(MemRW_ID),
        .ALUSrc_ID(ALUSrc_ID),
        .ALUControl_ID(ALUControl_ID),
        .Branch_ID(Branch_ID),
        .Jump_ID(Jump_ID),
        .ResultSrc_ID(ResultSrc_ID),
        .rb1111check_ID(rb1111check_ID),
        .LoadStoreSrc_ID(LoadStoreSrc_ID),
        .shift_amount_ID(shift_amount_ID),
        .BR_cond_ID(BR_cond_ID), // Added
        .ra(ra_ID),
        .rb(rb_ID),
        .rac_ID(rac_ID),
        .RD1_ID(RD1_ID),
        .RD2_ID(RD2_ID),
        .immExtend_ID(immExtend_ID),
        .PCTarget_ID(PCTarget_ID), // Jump target (ID stage)
        .PCSrc_ID(PCSrc_ID)        // Jump control (ID stage)
    );
    
    //-------------------------------------------------------------------------
    // HAZARD UNIT Signals & Instantiation
    //-------------------------------------------------------------------------
    // Wire declarations moved UP for HAZARD_UNIT
    wire        RegWrite_EX;
    wire [2:0]  MemRW_EX;       
    wire [1:0]  ALUSrc_EX;
    wire [3:0]  ALUControl_EX;
    wire        Branch_EX;
    wire        Jump_EX;
    wire [1:0]  ResultSrc_EX;
    wire        rb1111check_EX;
    wire [1:0]  LoadStoreSrc_EX;
    wire [5:0]  shift_amount_EX;
    wire [2:0]  BR_cond_EX; 
    wire [31:0] PC_EX;
    wire [31:0] RD1_EX;
    wire [31:0] RD2_EX;
    wire [31:0] immExtend_EX;
    wire [4:0]  ra_EX;
    wire [4:0]  rb_EX;
    wire [4:0]  rac_EX;         

    HAZARD_UNIT hazard_unit (
        .ra_ID(ra_ID),          
        .rb_ID(rb_ID),          
        .rac_EX(rac_EX),        
        .MemRW_EX(MemRW_EX),    
        .stall_pipeline(stall_pipeline) 
    );

    //-------------------------------------------------------------------------
    // ID/EX Pipeline Register
    //-------------------------------------------------------------------------
    reg_IDEX reg_idex (
        .CLK(CLK),
        .RSTN(RSTN),
        .stall_IDEX(stall_IDEX),
        .flush_IDEX(flush_IDEX),
        .RegWrite_ID(RegWrite_ID),
        .MemRW_ID(MemRW_ID),
        .ALUSrc_ID(ALUSrc_ID),
        .ALUControl_ID(ALUControl_ID),
        .Branch_ID(Branch_ID),
        .Jump_ID(Jump_ID),
        .ResultSrc_ID(ResultSrc_ID),
        .rb1111check_ID(rb1111check_ID),
        .LoadStoreSrc_ID(LoadStoreSrc_ID),
        .shift_amount_ID(shift_amount_ID),
        .BR_cond_ID(BR_cond_ID), 
        .PC_ID(PC_ID),
        .RD1_ID(RD1_ID),
        .RD2_ID(RD2_ID),
        .immExtend_ID(immExtend_ID),
        .ra_ID(ra_ID),
        .rb_ID(rb_ID),
        .rac_ID(rac_ID),
        .RegWrite_EX(RegWrite_EX),
        .MemRW_EX(MemRW_EX),
        .ALUSrc_EX(ALUSrc_EX),
        .ALUControl_EX(ALUControl_EX),
        .Branch_EX(Branch_EX),
        .Jump_EX(Jump_EX),
        .ResultSrc_EX(ResultSrc_EX),
        .rb1111check_EX(rb1111check_EX),
        .LoadStoreSrc_EX(LoadStoreSrc_EX),
        .shift_amount_EX(shift_amount_EX),
        .BR_cond_EX(BR_cond_EX), 
        .PC_EX(PC_EX),
        .RD1_EX(RD1_EX),
        .RD2_EX(RD2_EX),
        .immExtend_EX(immExtend_EX),
        .ra_EX(ra_EX),
        .rb_EX(rb_EX),
        .rac_EX(rac_EX)
    );

    //-------------------------------------------------------------------------
    // Forwarding Unit
    //-------------------------------------------------------------------------
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
    
    // Forward declarations for MEM stage signals needed by forwarding unit
    wire [4:0]  rac_MEM; 
    wire        RegWrite_MEM;

    FORWARDING forwarding_inst (
        .RSTN(RSTN),
        .ra_EX(ra_EX),
        .rb_EX(rb_EX),
        .ra_MEM(rac_MEM),
        .RegWrite_MEM(RegWrite_MEM),
        .ra_WB(rac_WB),
        .RegWrite_WB(RegWrite_WB),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );
    
    // Wires from EX Stage
    wire [31:0] ALU_result_EX;
    wire [31:0] RD1_EX_a; // Forwarded/Bypassed RD1
    wire [31:0] RD2_EX_a; // Forwarded/Bypassed RD2

    // Placeholder PCadd4_EX
    wire [31:0] PCadd4_EX = PC_EX + 32'd4;
    wire [31:0] ALU_result_MEM;

    stage_EX stage_ex (
        .ALUSrc_EX(ALUSrc_EX),
        .ALUControl_EX(ALUControl_EX),
        .Branch_EX(Branch_EX),
        .Jump_EX(Jump_EX),
        .rb1111check_EX(rb1111check_EX),
        .LoadStoreSrc_EX(LoadStoreSrc_EX),
        .shift_amount_EX(shift_amount_EX),
        .BR_cond_EX(BR_cond_EX), // Added
        .RD1_EX(RD1_EX),
        .RD2_EX(RD2_EX),
        .immExtend_EX(immExtend_EX),
        .PC_EX(PC_EX),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB),
        .Result_WB(Result_WB),
        .ALU_result_MEM(ALU_result_MEM), 
        .PCSrc_EX(PCSrc_EX),
        .PCTarget_EX(PCTarget_EX),
        .ALU_result_EX(ALU_result_EX),
        .RD1_EX_a(RD1_EX_a),
        .RD2_EX_a(RD2_EX_a)
    );

    //-------------------------------------------------------------------------
    // EX/MEM Pipeline Register
    //-------------------------------------------------------------------------
    wire [2:0]  MemRW_MEM;
    wire [1:0]  ResultSrc_MEM;
    wire [31:0] PC_MEM;
    wire [31:0] PCadd4_MEM;
    wire [31:0] RD2_MEM;
    // rac_MEM declared above

    reg_EXMEM reg_exmem (
        .CLK(CLK),
        .RSTN(RSTN),
        .stall_EXMEM(stall_EXMEM),
        .flush_EXMEM(flush_EXMEM),
        .RegWrite_EX(RegWrite_EX),
        .MemRW_EX(MemRW_EX),
        .ResultSrc_EX(ResultSrc_EX),
        .PC_EX(PC_EX),
        .PCadd4_EX(PCadd4_EX),
        .ALU_result_EX(ALU_result_EX),
        .RD2_EX(RD2_EX_a), // Use forwarded value for store
        .rac_EX(rac_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .MemRW_MEM(MemRW_MEM),
        .ResultSrc_MEM(ResultSrc_MEM),
        .PC_MEM(PC_MEM),
        .PCadd4_MEM(PCadd4_MEM),
        .ALU_result_MEM(ALU_result_MEM),
        .RD2_MEM(RD2_MEM),
        .rac_MEM(rac_MEM)
    );

    //-------------------------------------------------------------------------
    // MEM Stage (Interface Control)
    //-------------------------------------------------------------------------
    wire [31:0] ReadData_MEM;
    
    stage_MEM stage_mem (
        .MemRW_MEM(MemRW_MEM),
        .ALU_result_MEM(ALU_result_MEM),
        .RD2_MEM(RD2_MEM),
        .DREQ(DREQ),
        .DRW(DRW),
        .DADDR(DADDR),
        .DWDATA(DWDATA),
        .DRDATA(DRDATA),
        .ReadData_Out(ReadData_MEM)
    );

    //-------------------------------------------------------------------------
    // MEM/WB Pipeline Register
    //-------------------------------------------------------------------------
    wire [1:0]  ResultSrc_WB;
    wire [31:0] ReadData_WB;
    wire [31:0] ALU_result_WB;
    wire [31:0] PCadd4_WB;
    wire [31:0] PC_WB;  // Added for JL/BRL return address

    reg_MEMWB reg_memwb (
        .CLK(CLK),
        .RSTN(RSTN),
        .flush_MEMWB(flush_MEMWB),
        .RegWrite_MEM(RegWrite_MEM),
        .ResultSrc_MEM(ResultSrc_MEM),
        .ReadData_MEM(ReadData_MEM),
        .ALU_result_MEM(ALU_result_MEM),
        .PC_MEM(PC_MEM),
        .PCadd4_MEM(PCadd4_MEM),
        .rac_MEM(rac_MEM),
        .RegWrite_WB(RegWrite_WB),
        .ResultSrc_WB(ResultSrc_WB),
        .ReadData_WB(ReadData_WB),
        .ALU_result_WB(ALU_result_WB),
        .PCadd4_WB(PCadd4_WB),
        .PC_WB(PC_WB), 
        .rac_WB(rac_WB)
    );

    //-------------------------------------------------------------------------
    // WB Stage
    //-------------------------------------------------------------------------
    stage_WB stage_wb (
        .ResultSrc_WB(ResultSrc_WB),
        .ALU_result_WB(ALU_result_WB),
        .ReadData_MEM(ReadData_MEM),
        .PCadd4_WB(PCadd4_WB),
        .PC_WB(PC_WB), 
        .Result_WB(Result_WB)
    );

endmodule