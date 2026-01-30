module FORWARDING (
    input  wire       RSTN,
    
    // EX Stage Sources (현재 연산에 필요한 레지스터 번호)
    input  wire [4:0] ra_EX, // Source 1
    input  wire [4:0] rb_EX, // Source 2
    
    // MEM Stage Destination (직전 명령어의 목적지 - Forwarding Priority 1)
    input  wire [4:0] ra_MEM, // Write Address in MEM
    input  wire       RegWrite_MEM,
    
    // WB Stage Destination (전전 명령어의 목적지 - Forwarding Priority 2)
    input  wire [4:0] ra_WB,  // Write Address in WB
    input  wire       RegWrite_WB,
    
    // Forwarding Control Signals
    output reg [1:0]  ForwardA, // For Source 1
    output reg [1:0]  ForwardB  // For Source 2
);

    always @(*) begin
        // Default: No Forwarding (Use ID/EX Register Output)
        ForwardA = 2'b00;
        ForwardB = 2'b00;
        
        if (!RSTN) begin
            ForwardA = 2'b00;
            ForwardB = 2'b00;
        end else begin
            // ---------------------------------------------------------
            // Forwarding Logic for Source 1 (ra_EX)
            // ---------------------------------------------------------
            // Priority 1: EX Hazard (From MEM Stage)
            // MEM 단계에 있는 명령어가 RegWrite하고, 그 목적지가 현재 ra_EX와 같으면 (단, r0 제외)
            if (RegWrite_MEM && (ra_MEM != 5'b0) && (ra_MEM == ra_EX)) begin
                ForwardA = 2'b10; // Select ALU_result_MEM
            end
            // Priority 2: MEM Hazard (From WB Stage)
            // WB 단계에 있는 명령어가 RegWrite하고, 그 목적지가 현재 ra_EX와 같으면
            else if (RegWrite_WB && (ra_WB != 5'b0) && (ra_WB == ra_EX)) begin
                ForwardA = 2'b01; // Select Result_WB
            end
            

            // ---------------------------------------------------------
            // Forwarding Logic for Source 2 (rb_EX)
            // ---------------------------------------------------------
            // Priority 1: EX Hazard (From MEM Stage)
            if (RegWrite_MEM && (ra_MEM != 5'b0) && (ra_MEM == rb_EX)) begin
                ForwardB = 2'b10; // Select ALU_result_MEM
            end
            // Priority 2: MEM Hazard (From WB Stage)
            else if (RegWrite_WB && (ra_WB != 5'b0) && (ra_WB == rb_EX)) begin
                ForwardB = 2'b01; // Select Result_WB
            end

        end
    end

endmodule

