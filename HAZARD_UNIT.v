module HAZARD_UNIT (
    // ID
    input  wire [4:0] ra_ID,
    input  wire [4:0] rb_ID,

    // EX
    input  wire [4:0] rac_EX,
    input  wire [2:0] MemRW_EX, // EX Load 확인

    // 출력: Stall 신호
    output reg        stall_pipeline
);

    always @(*) begin
        stall_pipeline = 1'b0; // 기본값: 멈추지 않음

        // MemRW_EX[2]가 1이면 Load 계열 (LD, LDR, LDIP) 명령어라고 가정 (CONTROL.v 참조)
        // MemRW_EX: 101(LD/LDR), 111(LDIP) -> 3번째 비트([2])가 1이면 Read 동작
        if (MemRW_EX[2] == 1'b1) begin
            
            // Load 명령의 목적지(rac_EX)가 현재 명령어의 소스(ra_ID 또는 rb_ID)와 겹치면 Stall
            // 단, r0는 항상 0이므로 체크 제외
            if ( (rac_EX != 5'b0) && ((rac_EX == ra_ID) || (rac_EX == rb_ID)) ) begin
                stall_pipeline = 1'b1;
            end
        end
    end

endmodule