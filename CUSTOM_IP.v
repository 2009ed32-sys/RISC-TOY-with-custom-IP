module CUSTOM_IP(
    input   wire            CLK,
    input   wire            RSTN,
    input   wire   [31:0]   IPIN,
    input   wire   [31:0]   CON,    // [2]=start, [0]=mode(1:3x3)
    output  wire    [31:0]   IPOUT
);
    // -----------------------------------------------------------
    // 1. Data Buffer (Store raw inputs directly)
    // -----------------------------------------------------------
    reg [16:0] input_buffer [0:7];
    reg [31:0] IPOUT_reg;
    reg receiving_enable; 
    reg computing_enable;
    reg [3:0] cnt; 
    reg [4:0] exec_cnt; // Execution counter (0..31)

    wire start_bit = CON[2];
    wire is_3x3    = CON[0];
    wire init_bit   = CON[1]; // Initialize signal (clear input_buffer and C) 
    
    // Change Detection REMOVED: Rely on precise timing with Start bit.
    // reg [31:0] last_ipin;
    // wire ipin_changed = (IPIN != last_ipin);

    integer i;

    // MAC Array Signals
    reg clr_mac;
    reg update_ready;
    reg [1:0] mac_enable;
    
    reg signed [3:0] a_in_row [0:3];
    reg signed [3:0] b_in_col [0:3];

    wire signed [19:0] C[0:3][0:3];

    // Instantiate MAC Array
    macarray_4x4 u_mac_array (
        .CLK(CLK),
        .RSTN(RSTN),
        .clr(clr_mac),
        .enable(mac_enable),
        .update_ready(update_ready),

        .a_in_row0(a_in_row[0]), .a_in_row1(a_in_row[1]), .a_in_row2(a_in_row[2]), .a_in_row3(a_in_row[3]),
        .b_in_col0(b_in_col[0]), .b_in_col1(b_in_col[1]), .b_in_col2(b_in_col[2]), .b_in_col3(b_in_col[3]),

        .C00(C[0][0]), .C01(C[0][1]), .C02(C[0][2]), .C03(C[0][3]),
        .C10(C[1][0]), .C11(C[1][1]), .C12(C[1][2]), .C13(C[1][3]),
        .C20(C[2][0]), .C21(C[2][1]), .C22(C[2][2]), .C23(C[2][3]),
        .C30(C[3][0]), .C31(C[3][1]), .C32(C[3][2]), .C33(C[3][3]),
        
        .a_out()
    );

    // -----------------------------------------------------------
    // Control Logic
    // -----------------------------------------------------------
    reg last_start_bit;
    reg last_init_bit;

    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            receiving_enable <= 1'b0;
            computing_enable <= 1'b0;
            cnt <= 0;
            exec_cnt <= 0;
            clr_mac <= 0;
            last_start_bit <= 0;
            last_init_bit <= 0;
            
            // Initialize buffer
            for(i=0; i<8; i=i+1) begin
                input_buffer[i] <= 17'd0;
            end
        end
        else begin
            last_start_bit <= start_bit;
            last_init_bit <= init_bit;
            
            // 0. Initialize Logic (Complete Reset when init_bit is active)
            // When init_bit = 1, reset everything: input_buffer, C, and all control signals
            if (init_bit) begin
                // Clear input_buffer
                for(i=0; i<8; i=i+1) begin
                    input_buffer[i] <= 17'd0;
                end
                // Reset all control signals
                receiving_enable <= 1'b0;
                computing_enable <= 1'b0;
                cnt <= 0;
                exec_cnt <= 0;
                // Clear C (MAC array) - set clr_mac, update_ready, and mac_enable
                // Note: acc_clk needs enable & update_ready = 1 to toggle for clr to work
                clr_mac <= 1'b1;
                update_ready <= 1'b1;
                mac_enable <= (is_3x3) ? 2'b01 : 2'b11;
            end
            // 1. Receiving Logic (only if init_bit is not active)
            // Trigger: Rising edge of Start bit AND Not busy
            if (start_bit && !last_start_bit && !receiving_enable && !computing_enable) begin
                receiving_enable <= 1'b1;
                cnt <= 1; 
                // Initialize buffer to clear previous data
                for(i=0; i<8; i=i+1) begin
                    input_buffer[i] <= 17'd0;
                end
                input_buffer[0] <= IPIN[16:0]; // Capture 1st data
            end
            else if (receiving_enable) begin
                // [Fix] In 3x3 mode, force 4th (idx 3) and 8th (idx 7) rows to 0
                if (is_3x3 && (cnt == 3 || cnt == 7)) begin
                    input_buffer[cnt] <= 17'd0;
                end
                else begin
                    input_buffer[cnt] <= IPIN[16:0];
                end
                
                if (cnt == 7) begin
                    receiving_enable <= 1'b0;
                    cnt <= 0;
                    
                    // Start Computation
                    computing_enable <= 1'b1;
                    exec_cnt <= 0;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
            // 2. Computing Logic (only if init_bit is not active)
            if (computing_enable && !init_bit) begin
                exec_cnt <= exec_cnt + 1;
                
                if (exec_cnt == 0) begin
                    clr_mac <= 1'b1;
                    update_ready <= 1'b1; 
                    mac_enable <= (is_3x3) ? 2'b01 : 2'b11;
                end
                else if (exec_cnt == 1) begin
                    clr_mac <= 1'b0; // Clear off at cycle 1, ready for cycle 2 data
                end
                else if (exec_cnt > 12) begin 
                    computing_enable <= 1'b0;
                    update_ready <= 1'b0;
                    mac_enable <= 2'b00;
                    exec_cnt <= 0;
                end
            end
            else begin
                // Idle
                // If init_bit is active, keep clr_mac high for C initialization
                // Otherwise, clear all signals
                if (init_bit) begin
                    // Keep clr_mac, update_ready, mac_enable active for C initialization
                    clr_mac <= 1'b1;
                    update_ready <= 1'b1;
                    mac_enable <= (is_3x3) ? 2'b01 : 2'b11;
                end
                else begin
                    clr_mac <= 1'b0;
                    update_ready <= 1'b0;
                    mac_enable <= 2'b00;
                end
            end
        end
    end
    //---------------------------------------------
    // Data Feeding Logic (Skewing)
    // -----------------------------------------------------------
    function signed [3:0] get_element;
        input [16:0] row_data;
        input integer idx;
        begin
            case (idx)
                0: get_element = row_data[3:0];
                1: get_element = row_data[7:4];
                2: get_element = row_data[11:8];
                3: begin
                    if (is_3x3) get_element = 4'sd0;
                    else        get_element = row_data[15:12];
                end
                default: get_element = 4'sd0;
            endcase
        end
    endfunction

    integer k, r, c;
    always @(*) begin
        for (r=0; r<4; r=r+1) a_in_row[r] = 4'sd0;
        for (c=0; c<4; c=c+1) b_in_col[c] = 4'sd0;

        // Start feeding data later to avoid collision with Clear
        if (computing_enable && exec_cnt >= 2) begin
            k = exec_cnt - 2; // Shift time base: exec_cnt 2 -> k=0

            // A Input: Feed A[r][t] into Row r
            for (r=0; r<4; r=r+1) begin
                if ((k >= r) && (k < r + 4)) begin
                   if (!is_3x3 || r < 3) begin
                        a_in_row[r] = get_element(input_buffer[r], k - r);
                   end
                end
            end

            // B Input: Feed B[t][c] into Col c
            for (c=0; c<4; c=c+1) begin
                if ((k >= c) && (k < c + 4)) begin
                    if (!is_3x3 || c < 3) begin
                         // Buffer 4,5,6,7 are B rows (regardless of mode, since we fill 8 buffers)
                         // Value needed: B[k-c][c]. k-c is row index.
                         b_in_col[c] = get_element(input_buffer[4 + (k - c)], c);
                    end
                end
            end
        end
    end

    // -----------------------------------------------------------
    // Output Logic (Readout Mux)
    // -----------------------------------------------------------
    reg [3:0] add; 
    always @(*) begin
        if(CON[8]) begin
            // CON[7:6] = Row index, CON[5:4] = Col index
            IPOUT_reg = C[CON[7:6]][CON[5:4]];
            add = {CON[7:6], CON[5:4]};
        end else begin
            IPOUT_reg = 32'd0;
        end
    end// 내부 reg를 output wire에 연결
assign IPOUT = IPOUT_reg;

endmodule



