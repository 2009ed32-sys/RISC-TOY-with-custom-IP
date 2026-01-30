module CONTROL (
    input  wire [4:0]  opcode,
    input  wire [4:0]  rb,
    input  wire [2:0]  br_cond_field,

    output reg         RegWrite_ID,
    output reg  [2:0]  MemRW_ID,
    output reg  [1:0]  ALUSrc_ID,
    output reg  [3:0]  ALUControl_ID,
    output reg         Branch_ID,
    output reg         Jump_ID,
    output reg  [1:0]  ResultSrc_ID,
    output reg         rb1111check_ID,
    output reg  [1:0]  LoadStoreSrc_ID,
    output reg  [2:0]  BR_cond_ID
);

    always @(*) begin
        // --- Defaults ---
        RegWrite_ID     = 1'b0;
        MemRW_ID        = 3'b000;  // No memory access: bit[0]=0, bit[1:0]=00 
        ALUSrc_ID       = 2'b00; 
        ALUControl_ID   = 4'b0000;
        Branch_ID       = 1'b0;
        Jump_ID         = 1'b0;
        ResultSrc_ID    = 2'b00; 
        LoadStoreSrc_ID = 2'b00; 
        rb1111check_ID  = (rb == 5'b11111);
		  BR_cond_ID      = 3'b000;

        case (opcode)
            // --- R-type Ops ---
            5'b00000: begin RegWrite_ID = 1; ALUControl_ID = 4'b0000; end // ADD
            5'b00010: begin RegWrite_ID = 1; ALUControl_ID = 4'b0001; end // SUB
            5'b00011: begin RegWrite_ID = 1; ALUControl_ID = 4'b0110; end // NEG
            5'b00100: begin RegWrite_ID = 1; ALUControl_ID = 4'b0101; end // NOT
            5'b00101: begin RegWrite_ID = 1; ALUControl_ID = 4'b0010; end // AND
            5'b00111: begin RegWrite_ID = 1; ALUControl_ID = 4'b0011; end // OR
            5'b01001: begin RegWrite_ID = 1; ALUControl_ID = 4'b0100; end // XOR
            5'b01010: begin RegWrite_ID = 1; ALUControl_ID = 4'b1000; end // LSR
            5'b01011: begin RegWrite_ID = 1; ALUControl_ID = 4'b1001; end // ASR
            5'b01100: begin RegWrite_ID = 1; ALUControl_ID = 4'b0111; end // SHL
            5'b01101: begin RegWrite_ID = 1; ALUControl_ID = 4'b1010; end // ROR

            // --- I-type Ops ---
            5'b00001: begin // ADDI
                RegWrite_ID = 1; ALUSrc_ID = 2'b01; ALUControl_ID = 4'b0000;
            end
            5'b00110: begin // ANDI
                RegWrite_ID = 1; ALUSrc_ID = 2'b01; ALUControl_ID = 4'b0010;
            end
            5'b01000: begin // ORI
                RegWrite_ID = 1; ALUSrc_ID = 2'b01; ALUControl_ID = 4'b0011;
            end
            5'b01110: begin // MOVI
                RegWrite_ID = 1; ALUSrc_ID = 2'b01; ALUControl_ID = 4'b1011; 
            end

            // --- J-type Ops ---
            5'b01111: begin // J
                Jump_ID = 1; ALUSrc_ID = 2'b11; ALUControl_ID = 4'b1111;
            end
            5'b10000: begin // JL
                RegWrite_ID = 1; ResultSrc_ID = 2'b11; Jump_ID = 1; ALUControl_ID = 4'b1011; ALUSrc_ID = 2'b11;
                LoadStoreSrc_ID = 2'b01;
            end

            // --- B-type Ops ---
            5'b10001: begin // BR
                Branch_ID = 1'b1; BR_cond_ID = br_cond_field; ALUControl_ID = 4'b1011; ALUSrc_ID = 2'b00;
            end
            5'b10010: begin // BRL
                RegWrite_ID = 1; ResultSrc_ID = 2'b10; 
                Branch_ID = 1'b1; BR_cond_ID = br_cond_field;
                ALUControl_ID = 4'b1011; ALUSrc_ID = 2'b00;
                LoadStoreSrc_ID = 2'b00; // Register Indirect: use r2 value directly
            end

            // --- Memory Ops ---
            // MemRW encoding: [2:0]
            //   bit[0]: DREQ (1=memory access, 0=no access)
            //   bit[2:1]: DRW (WEN value for DATA_RAM)
            //   3'b001: Write DI1 (ST, STR) - DREQ=1, DRW=00
            //   3'b101: Read DOUT1 (LD, LDR) - DREQ=1, DRW=10
            //   3'b011: Write DI2 (STIP) - DREQ=1, DRW=01
            //   3'b111: Read DOUT2 (LDIP) - DREQ=1, DRW=11
            5'b10011: begin // ST
                MemRW_ID = 3'b001; ALUSrc_ID = 2'b01; LoadStoreSrc_ID = 2'b00;
                ALUControl_ID = 4'b0000; 
                rb1111check_ID = (rb == 5'b11111);
            end
            5'b10100: begin // STR
                MemRW_ID = 3'b001; ALUSrc_ID = 2'b01; LoadStoreSrc_ID = 2'b01; 
                ALUControl_ID = 4'b0000; 
            end
            5'b10101: begin // LD
                RegWrite_ID = 1; MemRW_ID = 3'b101; ALUSrc_ID = 2'b01; LoadStoreSrc_ID = 2'b00;
                ResultSrc_ID = 2'b01; ALUControl_ID = 4'b0000;
                rb1111check_ID = (rb == 5'b11111);
            end
            5'b10110: begin // LDR
                RegWrite_ID = 1; MemRW_ID = 3'b101; ALUSrc_ID = 2'b01; LoadStoreSrc_ID = 2'b01; 
                ResultSrc_ID = 2'b01; ALUControl_ID = 4'b0000;
            end

            // --- IP Ops ---
            5'b10111: begin // LDIP
                RegWrite_ID = 1'b0; MemRW_ID = 3'b111; ALUSrc_ID = 2'b01; 
                LoadStoreSrc_ID = 2'b10; 
                ResultSrc_ID = 2'b01; ALUControl_ID = 4'b1011; 
            end
            5'b11000: begin // STIP
                MemRW_ID = 3'b011; ALUSrc_ID = 2'b01; 
                LoadStoreSrc_ID = 2'b10; 
                ALUControl_ID = 4'b1011; 
            end

            // --- NOP (Explicit) ---
            5'b11111: begin
                ALUControl_ID = 4'b1111; // NOP
            end
        endcase
    end
endmodule

