module stage_MEM (
    // Control Signals from EX/MEM Reg
    input  wire [2:0]  MemRW_MEM,      // 00: Write, 10: Read (matches DATA_RAM WEN encoding)
    
    // Data from EX/MEM Reg
    input  wire [31:0] ALU_result_MEM, // Memory Address
    input  wire [31:0] RD2_MEM,  
    
    // input for STLD_Src      // Write Data (Store Value)
    input  wire [31:0] ALU_result_EX,
    
    // Interface to External Data Memory
    output wire        DREQ,           // Data Request (Chip Select)
    output wire [1:0]  DRW,            // Read/Write Control
    output wire [31:0] DADDR,          // Word Aligned Address
    output wire [31:0] DWDATA,         // Write Data Output
    input  wire [31:0] DRDATA,         // Read Data Input
    
    // Output to MEM/WB Reg
    output wire [31:0] ReadData_Out    // Data to be written back to Register
);

    // 1. Memory Request Generation
    // MemRW_MEM: 00=Write DI1, 10=Read DOUT1, 01=Write DI2, 11=READ DOUT2
    // 메모리 접근이 필요한 경우만 DREQ 활성화
    assign DREQ = MemRW_MEM[0];
    
    // 2. Read/Write Control
    // MemRW_MEM[2:1]이 DATA_RAM WEN과 일치하므로 bit[2:1]을 사용
    // bit[0]: DREQ, bit[2:1]: DRW
    assign DRW[1:0] = MemRW_MEM[2:1]; 
    
    // 3. Address Generation
    // Testbench slices [11:2], so we must provide Byte Address (not Word Address)
    assign DADDR = ALU_result_MEM; 
    
    // 4. Write Data
    assign DWDATA = RD2_MEM;

    // 5. Read Data Pass-through
    // Load 명령어 실행 시 메모리에서 온 데이터를 WB 단계로 전달
    assign ReadData_Out = DRDATA;

endmodule
