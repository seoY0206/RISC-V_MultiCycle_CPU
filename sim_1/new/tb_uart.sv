`timescale 1ns / 1ps

// --- APB 인터페이스 ---
// (기존 tb_uart.sv와 동일)
interface apb_if (
    input logic PCLK,
    input logic PRESET
);
    logic [ 3:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic        PSEL;
    logic [31:0] PRDATA;
    logic        PREADY;
endinterface

// --- UART 신호용 인터페이스 ---
// (tb_fifo.sv 스타일처럼 tx/rx를 인터페이스로 묶음)
interface uart_if (
    input logic PCLK // RX 드라이버 동기화용
);
    logic tx;
    logic rx;
endinterface


// --- APB 드라이버 클래스 ---
// (기존 ApbUartTester를 드라이버 클래스로 변형)
class apb_driver;
    virtual apb_if vif; 
    logic [ 3:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    function new(virtual apb_if vif);
        this.vif = vif;
    endfunction

    // APB 쓰기 태스크
    task automatic send();
        @(posedge vif.PCLK);
        vif.PSEL   <= 1'b1;
        vif.PADDR  <= this.addr;
        vif.PWDATA <= this.wdata;
        vif.PWRITE <= 1'b1;
        vif.PENABLE<= 1'b0;
        @(posedge vif.PCLK); // SETUP
        vif.PENABLE<= 1'b1; // ACCESS
        wait (vif.PREADY);
        @(posedge vif.PCLK);
        vif.PSEL   <= 1'b0;
        vif.PENABLE<= 1'b0;
    endtask

    // APB 읽기 태스크
    task automatic receive();
        @(posedge vif.PCLK);
        vif.PSEL   <= 1'b1;
        vif.PADDR  <= this.addr;
        vif.PWRITE <= 1'b0;
        vif.PENABLE<= 1'b0;
        @(posedge vif.PCLK); // SETUP
        vif.PENABLE<= 1'b1; // ACCESS
        wait (vif.PREADY);
        this.rdata = vif.PRDATA; // 데이터 읽기
        @(posedge vif.PCLK);
        vif.PSEL   <= 1'b0;
        vif.PENABLE<= 1'b0;
    endtask
endclass

// --- UART (RX) 드라이버 클래스 ---
// (UART RX 핀을 구동하는 태스크를 포함)
class uart_driver;
    virtual uart_if vif;
    
    function new(virtual uart_if vif);
        this.vif = vif;
    endfunction

    // RX 핀으로 1바이트 전송 (PCLK negedge 기준)
    task automatic drive_rx_char(input logic [7:0] char);
        const int CLK_PER_BIT = 10416; // 1비트 당 클럭 수
        
        $display("[%.0fns] (RX Driver) 0x%h 전송 시작...", $time, char);
        @(negedge vif.PCLK); vif.rx = 1'b0; // Start
        repeat(CLK_PER_BIT) @(posedge vif.PCLK);
        
        for (int i = 0; i < 8; i++) begin // Data
            @(negedge vif.PCLK);
            vif.rx = char[i];
            repeat(CLK_PER_BIT) @(posedge vif.PCLK);
        end
        
        @(negedge vif.PCLK);
        vif.rx = 1'b1; // Stop
        repeat(CLK_PER_BIT) @(posedge vif.PCLK);

        @(negedge vif.PCLK); vif.rx = 1'b1; // Idle
        $display("[%.0fns] (RX Driver) 0x%h 전송 완료.", $time, char);
    endtask
endclass


// --- 테스트 환경 클래스 ---
// (tb_fifo.sv의 fifo_env와 유사한 역할)
class uart_env;
    // 가상 인터페이스 핸들
    virtual apb_if  apb_vif;
    virtual uart_if uart_vif;

    // 드라이버 핸들
    apb_driver  drv_apb;
    uart_driver drv_uart;

    // 테스트 데이터 배열
    parameter TX_COUNT = 5;
    parameter RX_COUNT = 2;
    static logic [7:0] tx_array[TX_COUNT];
    static logic [7:0] rx_array[RX_COUNT];
    static logic [7:0] received_array[RX_COUNT];

    // 생성자
    function new(virtual apb_if apb_vif, virtual uart_if uart_vif);
        this.apb_vif  = apb_vif;
        this.uart_vif = uart_vif;
    endfunction

    // 컴포넌트 빌드 (tb_fifo.sv의 build와 유사)
    task build();
        drv_apb  = new(apb_vif);
        drv_uart = new(uart_vif);
    endtask

    // 테스트 데이터 초기화
    task init_data();
        tx_array[0] = 8'h48; // 'H'
        tx_array[1] = 8'h65; // 'e'
        tx_array[2] = 8'h6C; // 'l'
        tx_array[3] = 8'h6C; // 'l'
        tx_array[4] = 8'h6F; // 'o'

        rx_array[0] = 8'h54; // 'T'
        rx_array[1] = 8'h42; // 'B'
    endtask

    // --- TX FIFO 테스트 시나리오 ---
    task run_tx_test();
        automatic logic [7:0] char_to_send;
        $display("[%.0fns] --- TX FIFO 테스트 시작 (5글자 전송) ---", $time);
        
        for (int i = 0; i < TX_COUNT; i = i + 1) begin
            char_to_send = tx_array[i];
            
            // 1. STATUS(0x8)를 읽어 tx_fifo_full(bit 0)이 0인지 확인
            $display("[%.0fns] TX: 0x%h 전송 대기 (TX FIFO 공간 확인 중)...", $time, char_to_send);
            drv_apb.addr = 4'h8; // STATUS
            do begin
                drv_apb.receive();
                if (drv_apb.rdata[0] == 1) begin
                    $display("[%.0fns] TX FIFO 꽉 참. 대기 중...", $time);
                    #100_000; // 잠시 대기
                end
            end while (drv_apb.rdata[0] == 1); // rdata[0] == tx_fifo_full

            // 2. TX_DATA(0x0)에 문자 쓰기
            $display("[%.0fns] TX: 공간 확인. 0x%h 쓰는 중...", $time, char_to_send);
            drv_apb.addr  = 4'h0; // TX_DATA
            drv_apb.wdata = {24'h0, char_to_send};
            drv_apb.send();
        end

        $display("[%.0fns] TX: 'Hello' 5글자 모두 TX FIFO에 쓰기 완료.", $time);
        #6_000_000; // 약 6ms 대기 (UART 전송 완료 대기)
        $display("[%.0fns] --- TX FIFO 테스트 종료 ---", $time);
    endtask

    // --- RX FIFO 테스트 시나리오 ---
    task run_rx_test();
        automatic logic [7:0] char_received;
        automatic bit match;
        automatic int received_count = 0;

        $display("[%.0fns] --- RX FIFO 테스트 시작 (2글자 수신) ---", $time);
        
        // 1. (병렬) `drive_rx_char` 태스크로 'T', 'B' 연속 전송 시작
        fork
            begin
                for (int j = 0; j < RX_COUNT; j = j + 1) begin
                   drv_uart.drive_rx_char(rx_array[j]);
                end
            end
        join_none // 백그라운드 실행

        // 2. (메인) 보낸 만큼 (2글자) RX FIFO에서 읽어오기
        for (int i = 0; i < RX_COUNT; i = i + 1) begin
            // 2a. STATUS(0x8)를 읽어 rx_fifo_empty(bit 1)가 0인지 확인
            $display("[%.0fns] RX: %0d번째 문자 수신 대기 중 (RX FIFO 확인 중)...", $time, i+1);
            drv_apb.addr = 4'h8; // STATUS
            do begin
                drv_apb.receive();
                if (drv_apb.rdata[1] == 1) begin
                    #100_000; // FIFO가 비어있으면 잠시 대기
                end
            end while (drv_apb.rdata[1] == 1); // rdata[1] == rx_fifo_empty

            // 2b. RX_DATA(0xC)에서 문자 읽기
            $display("[%.0fns] RX: 데이터 감지. RX_DATA(0xC) 읽는 중...", $time);
            drv_apb.addr = 4'hC; // RX_DATA
            drv_apb.receive();
            
            char_received = drv_apb.rdata[7:0];
            received_array[received_count] = char_received;
            received_count = received_count + 1;
            $display("[%.0fns] RX: 0x%h 수신.", $time, char_received);
        end

        // 3. 수신 완료 후 데이터 검증
        if (RX_COUNT != received_count) begin
            $display("[%.0fns] --- RX FIFO 테스트 실패! (수신 카운트 불일치) ---", $time);
        end else begin
            match = 1;
            for (int i = 0; i < RX_COUNT; i = i + 1) begin
                if (rx_array[i] != received_array[i]) begin
                    $display("[%.0fns] --- RX FIFO 테스트 실패! (데이터 불일치) ---", $time);
                    $display("기대값[%0d]: 0x%h, 수신값[%0d]: 0x%h", i, rx_array[i], i, received_array[i]);
                    match = 0;
                end
            end
            if (match) begin
                $display("[%.0fns] --- RX FIFO 테스트 성공! (데이터 일치) ---", $time);
            end
        end
        
        // (최종) RX FIFO가 다시 비었는지 확인
        drv_apb.addr = 4'h8; // STATUS
        drv_apb.receive();
        if (drv_apb.rdata[1] == 1) begin // rdata[1] == rx_fifo_empty
             $display("[%.0fns] RX: 최종 확인. RX FIFO가 비어있음.", $time);
        end else begin
             $display("[%.0fns] RX: 최종 확인 실패. RX FIFO에 데이터가 남아있음.", $time);
        end

    endtask

    // --- 메인 테스트 시퀀스 (tb_fifo.sv의 run_test와 유사) ---
    task run_main_test();
        // 1. 테스트 데이터 초기화
        init_data();
        
        // 2. TX 테스트 실행
        run_tx_test();

        #2_000_000; // 2ms 대기

        // 3. RX 테스트 실행
        run_rx_test();

        #2000;
        $display("[%.0fns] --- 전체 FIFO 테스트 종료 ---", $time);
        $stop;
    endtask

endclass


// --- 테스트벤치 최상위 모듈 ---
// (tb_fifo.sv처럼 매우 간결하게 유지)
module tb_uart_fifo;
    logic PCLK = 0;
    logic PRESET;

    // 100MHz 클럭 (10ns 주기)
    always #5 PCLK = ~PCLK;

    // 인터페이스 인스턴스화
    apb_if  apb_bus  (PCLK, PRESET);
    uart_if uart_bus (PCLK); // PCLK 전달

    // DUT 인스턴스화
    UART_Periph dut (
        .PCLK   (PCLK),
        .PRESET (PRESET),
        // APB 인터페이스 연결
        .PADDR  (apb_bus.PADDR), 
        .PWRITE (apb_bus.PWRITE),
        .PENABLE(apb_bus.PENABLE),
        .PWDATA (apb_bus.PWDATA),
        .PSEL   (apb_bus.PSEL),
        .PRDATA (apb_bus.PRDATA),
        .PREADY (apb_bus.PREADY),
        // UART 인터페이스 연결
        .tx     (uart_bus.tx),
        .rx     (uart_bus.rx) 
    );

    // 테스트 환경 인스턴스
    uart_env env;

    // --- 테스트 실행 ---
    initial begin
        // 1. 환경 생성 및 인터페이스 연결
        env = new(apb_bus, uart_bus);

        // 2. 환경 빌드 (드라이버 생성)
        env.build();

        // 3. 리셋 및 초기화
        #00;
        PRESET = 1; 
        uart_bus.rx = 1'b1; // RX는 Idle
        #20;
        PRESET = 0; // 리셋 해제
        repeat(3) @(posedge PCLK); // 안정화 대기
        
        // 4. 메인 테스트 실행
        env.run_main_test();
    end

endmodule