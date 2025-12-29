`timescale 1ns / 1ps

/*
 * UART APB Peripheral (FIFO 내장 버전)
 * - 모든 내부 모듈 동기 리셋 적용
 */
module UART_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET, // Expecting synchronous reset signal
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    output logic tx,
    input  logic rx
);

    // APB 레지스터
    logic [31:0] slv_reg0; // TX_DATA 쓰기용

    // FIFO와 uart 코어 간의 내부 신호
    logic        apb_tx_wr_en;
    logic [7:0]  apb_tx_wr_data;
    logic        tx_fifo_full;
    logic        apb_rx_rd_en;
    logic [7:0]  apb_rx_rd_data;
    logic        rx_fifo_empty;


    // FIFO가 내장된 UART 코어 모듈 인스턴스화
    uart U_UART (
        .clk        (PCLK),
        .rst        (PRESET), // Pass synchronous reset

        // APB -> TX FIFO
        .apb_tx_wr_en  (apb_tx_wr_en),
        .apb_tx_wr_data(apb_tx_wr_data),
        .tx_fifo_full  (tx_fifo_full),
        .tx            (tx),

        // Serial Input
        .rx            (rx),

        // RX FIFO -> APB
        .apb_rx_rd_en  (apb_rx_rd_en),
        .apb_rx_rd_data(apb_rx_rd_data),
        .rx_fifo_empty (rx_fifo_empty)
    );

    // --- APB 신호 정의 ---
    logic apb_access;
    assign apb_access = PSEL && PENABLE;

    // --- 1. PREADY 로직 (Corrected for 0-wait state) ---
    always_ff @(posedge PCLK) begin // Synchronous reset
        if (PRESET) begin
            PREADY <= 1'b0;
        end else begin
            PREADY <= PSEL; // Correct logic
        end
    end

    // --- 2. 레지스터 쓰기 로직 (TX_DATA only) ---
    always_ff @(posedge PCLK) begin // Synchronous reset
        if (PRESET) begin
            slv_reg0 <= 32'b0;
        end else begin
            if (apb_access && PWRITE) begin
                if (PADDR[3:2] == 2'd0) begin // TX_DATA address (0x0)
                    slv_reg0 <= PWDATA;
                end
            end
        end
    end

    // --- 3. PRDATA 읽기 로직 (STATUS and RX_DATA) ---
    always_comb begin
        PRDATA = 32'b0; // Default
        if (apb_access && ~PWRITE) begin
            case (PADDR[3:2])
                // STATUS address (0x8)
                2'd2: PRDATA = {30'b0, rx_fifo_empty, tx_fifo_full};
                // RX_DATA address (0xC)
                2'd3: PRDATA = {24'b0, apb_rx_rd_data};
                default: PRDATA = 32'b0;
            endcase
        end
    end

    // --- 4. FIFO 제어 신호 생성 로직 ---
    // Write to TX FIFO if writing to TX_DATA (0x0) and FIFO not full
    assign apb_tx_wr_en = (apb_access && PWRITE && (PADDR[3:2] == 2'd0) && !tx_fifo_full);
    assign apb_tx_wr_data = PWDATA[7:0]; // Use latched value

    // Read from RX FIFO if reading from RX_DATA (0xC) and FIFO not empty
    assign apb_rx_rd_en = (apb_access && ~PWRITE && (PADDR[3:2] == 2'd3) && !rx_fifo_empty);

endmodule


// ===================================================================
//
//               UART 핵심 로직 (FIFO 인스턴스화)
//
// ===================================================================
module uart (
    input clk,
    input rst, // Expecting synchronous reset

    // TX 측
    input       apb_tx_wr_en,
    input [7:0] apb_tx_wr_data,
    output      tx_fifo_full,
    output      tx,

    // RX 측
    input       rx,
    input       apb_rx_rd_en,
    output [7:0] apb_rx_rd_data,
    output      rx_fifo_empty
);

    parameter FIFO_DEPTH = 16;

    // --- 내부 신호 ---
    wire        w_b_tick;

    // TX FIFO <-> uart_tx 연결
    logic       tx_fifo_rd_en;
    logic [7:0] tx_fifo_rd_data;
    logic       tx_fifo_empty;
    logic       tx_engine_busy;
    logic       tx_engine_start;

    // uart_rx <-> RX FIFO 연결
    logic       rx_engine_done;
    logic [7:0] rx_engine_data;
    logic       rx_fifo_full;


    // --- 1. TX FIFO 인스턴스화 ---
    fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) tx_fifo_inst (
        .clk     (clk),
        .rst     (rst), // Pass synchronous reset
        .wr_en   (apb_tx_wr_en),
        .wr_data (apb_tx_wr_data),
        .full    (tx_fifo_full),
        .rd_en   (tx_fifo_rd_en),
        .rd_data (tx_fifo_rd_data),
        .empty   (tx_fifo_empty)
    );

    // --- 2. RX FIFO 인스턴스화 ---
    fifo #(
        .DATA_WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) rx_fifo_inst (
        .clk     (clk),
        .rst     (rst), // Pass synchronous reset
        .wr_en   (rx_engine_done),
        .wr_data (rx_engine_data),
        .full    (rx_fifo_full),
        .rd_en   (apb_rx_rd_en),
        .rd_data (apb_rx_rd_data),
        .empty   (rx_fifo_empty)
    );

    // --- 3. TX 엔진 자동 구동 로직 (Final Pulse Generation) ---
    logic read_request;
    logic read_request_dly, read_request_dly_prev;

    assign read_request = !tx_fifo_empty && !tx_engine_busy;

    always_ff @(posedge clk) begin // Synchronous reset
        if (rst) begin
            read_request_dly <= 1'b0;
            read_request_dly_prev <= 1'b0;
        end else begin
            read_request_dly <= read_request;
            read_request_dly_prev <= read_request_dly;
        end
    end

    assign tx_engine_start = read_request_dly && !read_request_dly_prev;
    assign tx_fifo_rd_en = tx_engine_start;


    // --- 4. 보레이트 생성기 ---
    baudrate_tick_gen U_TICK_GEN (
        .clk      (clk),
        .rst      (rst), // Pass synchronous reset
        .o_b_tick (w_b_tick)
    );

    // --- 5. RX 엔진 ---
    uart_rx U_UART_RX (
        .clk       (clk),
        .rst       (rst), // Pass synchronous reset
        .rx        (rx),
        .b_tick    (w_b_tick),
        .rx_data   (rx_engine_data),
        .rx_done   (rx_engine_done)
    );

    // --- 6. TX 엔진 ---
    uart_tx U_UART_TX (
        .clk       (clk),
        .rst       (rst), // Pass synchronous reset
        .tx_start  (tx_engine_start),
        .tx_data   (tx_fifo_rd_data),
        .b_tick    (w_b_tick),
        .tx_busy   (tx_engine_busy),
        .tx        (tx)
    );

endmodule


// ===================================================================
//
//             uart_rx (수신) 모듈
//
// ===================================================================
module uart_rx (
    input clk,
    input rst, // Expecting synchronous reset
    input rx,
    input b_tick,
    output [7:0] rx_data,
    output       rx_done
);
    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_reg, b_tick_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] rx_data_reg, rx_data_next;
    reg       rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg; // 1-clock pulse


    // [FINAL SYNC RESET V2] Changed to synchronous reset
    always_ff @(posedge clk) begin
        if (rst) begin
            c_state     <= IDLE;
            b_tick_reg  <= 0;
            bit_cnt_reg <= 0;
            rx_data_reg <= 0;
            rx_done_reg <= 0;
        end else begin
            c_state     <= n_state;
            b_tick_reg  <= b_tick_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_data_reg <= rx_data_next;
            rx_done_reg <= rx_done_next;
        end
    end

    // Combinational logic for next state and outputs
    always_comb begin
        n_state      = c_state;
        b_tick_next  = b_tick_reg;
        bit_cnt_next = bit_cnt_reg;
        rx_data_next = rx_data_reg;
        rx_done_next = 1'b0; // Default pulse to 0

        case (c_state)
            IDLE: begin
                if (~rx) begin // Start bit detected
                    b_tick_next = 0;
                    n_state = START;
                end
            end

            START: begin // Wait for middle of start bit
                if (b_tick) begin
                    if (b_tick_reg == 7) begin // Center sampling
                        b_tick_next  = 0;
                        n_state      = DATA;
                        bit_cnt_next = 0;     // Reset bit counter
                        rx_data_next = 8'h00; // Reset data register
                    end else begin
                        b_tick_next = b_tick_reg + 1;
                    end
                end
            end

            DATA: begin // Receive data bits
                if (b_tick) begin
                    if (b_tick_reg == 15) begin // End of bit period
                        b_tick_next  = 0;
                        // Shift in received bit (LSB first)
                        rx_data_next = {rx, rx_data_reg[7:1]};

                        if (bit_cnt_reg == 7) begin // All 8 bits received
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_next = b_tick_reg + 1;
                    end
                end
            end

            STOP: begin // Wait for stop bit
                if (b_tick) begin
                    if (b_tick_reg == 15) begin
                        rx_done_next = 1'b1; // Generate done pulse
                        n_state = IDLE;
                    end else begin
                        b_tick_next = b_tick_reg + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule


// ===================================================================
//
//             uart_tx (송신) 모듈
//
// ===================================================================
module uart_tx (
    input clk,
    input rst, // Expecting synchronous reset
    input tx_start, // 1-clock pulse to start transmission
    input b_tick,
    input [7:0] tx_data, // Data to transmit
    output tx_busy, // High during transmission
    output tx       // Serial output pin
);
    localparam [1:0] IDLE = 0, TX_START = 1, TX_DATA = 2, TX_STOP = 3;

    reg [1:0] state_reg, state_next;
    reg tx_busy_reg, tx_busy_next;
    reg tx_reg, tx_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx_busy = tx_busy_reg;
    assign tx      = tx_reg;

    // [FINAL SYNC RESET V2] Already synchronous, no change needed
    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg      <= IDLE;
            tx_busy_reg    <= 1'b0;
            tx_reg         <= 1'b1; // Idle high
            data_buf_reg   <= 8'b0;
            b_tick_cnt_reg <= 4'b0;
            bit_cnt_reg    <= 3'b0;
        end else begin
            state_reg      <= state_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end

    // Combinational logic for next state and outputs
    always_comb begin
        state_next      = state_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;     // Output idle high
                tx_busy_next = 1'b0; // Not busy
                // [FINAL IDLE Counter Reset Fix] Reset counters in IDLE
                b_tick_cnt_next = 4'b0;
                bit_cnt_next = 3'b0;

                if (tx_start) begin // Start pulse received
                    data_buf_next = tx_data; // Latch data
                    state_next = TX_START;
                    // b_tick_cnt_next is already 0
                end
            end

            TX_START: begin // Send start bit (0)
                tx_next = 1'b0;
                tx_busy_next = 1'b1; // Now busy
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin // End of start bit
                        state_next = TX_DATA;
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0; // Start with bit 0
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_DATA: begin // Send data bits (LSB first)
                tx_next = data_buf_reg[0]; // Output LSB
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin // End of bit period
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin // All 8 bits sent
                            state_next = TX_STOP;
                        end else begin
                            bit_cnt_next    = bit_cnt_reg + 1;
                            data_buf_next   = data_buf_reg >> 1; // Shift data for next bit
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_STOP: begin // Send stop bit (1)
                tx_next = 1'b1;
                tx_busy_next = 1'b1; // Still busy during stop bit
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin // End of stop bit
                        state_next = IDLE; // Return to idle
                        // tx_busy goes low in IDLE state
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            default: state_next = IDLE;
        endcase
    end
endmodule


// ===================================================================
//
//             baudrate_tick_gen 모듈
//
// ===================================================================
module baudrate_tick_gen (
    input  clk,
    input  rst, // Expecting synchronous reset
    output o_b_tick // 1-clock pulse at 16x baud rate
);
    parameter BAUD = 9600;
    // Calculate counter limit for 16x baud rate
    parameter BAUD_TICK_COUNT = (100_000_000 / (BAUD * 16)) - 1; // e.g., 650 for 100MHz

    // Use integer for counter, simplifies range calculation
    integer counter_reg; // Simpler counter
    reg b_tick_reg;

    assign o_b_tick = b_tick_reg;

    // [FINAL SYNC RESET V2] Changed to synchronous reset
    always_ff @(posedge clk) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 1'b0;
        end else begin
            b_tick_reg <= 1'b0; // Default pulse to 0
            if (counter_reg == BAUD_TICK_COUNT) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1; // Generate pulse
            end else begin
                counter_reg <= counter_reg + 1;
            end
        end
    end
endmodule