`timescale 1ns / 1ps

/* --- 리셋 동기화 및 디바운서 (전원 켜짐 + 버튼) ---
 * 1. 전원 인가 시(업로드 시) 10ms 동안 active-high 리셋 펄스 생성
 * 2. 버튼(active-high) 입력의 바운싱(노이즈)을 제거
 */
module Reset_System (
    input  logic clk,           // 100MHz 클럭
    input  logic btn_in,        // 보드 버튼 입력 (노이즈 있음)
    output logic rst_out        // CPU/주변장치로 가는 깨끗한 리셋
);
    // 10ms = 10,000,000 ns = 1,000,000 클럭 사이클 @ 100MHz
    // 2^20 = 1,048,576
    localparam CNT_MAX = 20'd1_000_000;
    
    reg [19:0] por_count_reg; // Power-On-Reset(전원 켜짐) 카운터
    reg        por_done;      // 전원 켜짐 리셋 완료 플래그

    reg        btn_sync1, btn_sync2, btn_sync3;
    
    // --- 1. 전원 켜짐 리셋 생성 (POR) ---
    // (모든 FF는 전원 인가 시 0으로 초기화됨)
    always_ff @(posedge clk) begin
        if (por_done == 1'b0) begin
            if (por_count_reg == CNT_MAX) begin
                por_done <= 1'b1;
            end else begin
                por_count_reg <= por_count_reg + 1'b1;
            end
        end
    end
    
    // --- 2. 버튼 입력 동기화 및 디바운싱 ---
    // 3단 동기화기로 버튼 입력을 동기화 (노이즈 필터링)
    always_ff @(posedge clk) begin
        btn_sync1 <= btn_in;
        btn_sync2 <= btn_sync1;
        btn_sync3 <= btn_sync2;
    end
    
    // --- 3. 최종 리셋 신호 생성 ---
    // rst_out은 (전원 켜짐 리셋이 끝나지 않았거나) OR (버튼이 눌렸을 때) 1이 됨
    assign rst_out = (por_done == 1'b0) | btn_sync3;

endmodule


module MCU (
    input  logic       clk,
    input  logic       reset_btn_in,
    // External Port
    output logic [7:0] gpo,
    input  logic [7:0] gpi,
    // inout  logic [7:0] gpio 

    output logic uart_tx,
    input  logic uart_rx
);

    wire         PCLK = clk;
    wire         mcu_clean_reset;
    
    // --- Reset_System 인스턴스화 ---
    Reset_System U_RESET_SYS (
        .clk     (PCLK),
        .btn_in  (reset_btn_in),     // 보드 핀(U18)의 노이즈 신호
        .rst_out (mcu_clean_reset)   // 깨끗한 리셋 신호
    );
    
    wire         PRESET = mcu_clean_reset; // <-- APB 마스터가 사용할 신호


    // Internal Interface Signals
    logic        transfer;
    logic        ready;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    logic [31:0] instrCode;
    logic [31:0] instrMemAddr;
    logic        busWe;
    logic [31:0] busAddr;
    logic [31:0] busWData;
    logic [31:0] busRData;

    // APB Interface Signals
    logic [31:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;

    logic        PSEL_RAM;
    logic        PSEL_GPO;
    logic        PSEL_GPI;
    logic        PSEL_GPIO;
    logic        PSEL_UART;

    logic [31:0] PRDATA_RAM;
    logic [31:0] PRDATA_GPO;
    logic [31:0] PRDATA_GPI;
    logic [31:0] PRDATA_UART;

    logic        PREADY_RAM;
    logic        PREADY_GPO;
    logic        PREADY_GPI;
    logic        PREADY_GPIO;
    logic        PREADY_UART;

    assign write = busWe;
    assign addr = busAddr;
    assign wdata = busWData;
    assign busRData = rdata;


    ROM U_ROM (
        .addr(instrMemAddr),
        .data(instrCode)
    );

    CPU_RV32I U_RV32I (
        .*,
        .reset(mcu_clean_reset)
        );

    APB_Master U_APB_Master (
        .*,
        .PRESET (PRESET),
        .PSEL0  (PSEL_RAM),
        .PSEL1  (),
        .PSEL2  (PSEL_GPO),
        .PSEL3  (PSEL_UART),

        .PRDATA0(PRDATA_RAM),
        .PRDATA1(),
        .PRDATA2(PRDATA_GPO),
        .PRDATA3(PRDATA_UART),

        .PREADY0(PREADY_RAM),
        .PREADY1(),
        .PREADY2(PREADY_GPO),
        .PREADY3(PREADY_UART)
    );

    RAM U_RAM (
        .*,
        .PRESET (PRESET),
        .PSEL  (PSEL_RAM),
        .PADDR (PADDR[11:0]),  
        .PRDATA(PRDATA_RAM),
        .PREADY(PREADY_RAM)
    );

    GPO_Periph U_GPO_Periph (
        .*,
        .PSEL  (PSEL_GPO),
        .PRDATA(PRDATA_GPO),
        .PREADY(PREADY_GPO)
    );

    GPI_Periph U_GPI_Periph (
        .*,
        .PSEL  (PSEL_GPI),
        .PRDATA(PRDATA_GPI),
        .PREADY(PREADY_GPI)
    );

    // GPIO_Periph U_GPIO_Periph (
    //     .*,
    //     .PSEL(PSEL_GPIO),
    //     .PRDATA(PRDATA_GPIO),
    //     .PREADY(PREADY_GPIO)
    // );   

    UART_Periph U_UART_Periph (  
        .PCLK   (PCLK),     
        .PRESET (PRESET),   
        .PADDR  (PADDR[3:0]),  
        .PWRITE (PWRITE),    
        .PENABLE(PENABLE),  
        .PWDATA (PWDATA),   
        .PSEL   (PSEL_UART),  
        .PRDATA (PRDATA_UART),
        .PREADY (PREADY_UART),
        .tx     (uart_tx),    
        .rx     (uart_rx)     
    );

endmodule
