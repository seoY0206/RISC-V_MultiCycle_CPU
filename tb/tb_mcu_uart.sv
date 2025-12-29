`timescale 1ns / 1ps


module tb_mcu_uart();

    // 1. 신호 선언
    logic clk;
    logic reset;
    
    // MCU 출력
    logic [7:0] gpo;
    logic       uart_tx;
    
    // MCU 입력 (테스트를 위해 0 또는 1로 고정)
    logic [7:0] gpi = 8'h00;
    logic       uart_rx = 1'b1; // UART RX는 IDLE(1) 상태로 고정

    // 2. 100MHz 클럭 생성 (10ns 주기)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 3. DUT (MCU) 인스턴스화
    MCU dut (
        .clk     (clk),
        .reset_btn_in   (reset),
        
        // 출력 포트
        .gpo     (gpo),
        .uart_tx (uart_tx),
        
        // 입력 포트
        .gpi     (gpi),
        .uart_rx (uart_rx)
    );

    // 4. 테스트 시퀀스
    initial begin
        $display("[%.0fns] --- MCU Top TB 시작 ---", $time);
        
        // 리셋 적용
        reset = 1'b1;
        #20;
        reset = 1'b0;
        $display("[%.0fns] 리셋 해제. CPU 부팅 및 code.mem 실행 시작.", $time);

        // CPU가 "Hello"를 전송하기에 충분한 시간 (10ms) 대기
        #8_000_000; 
        
        $display("[%.0fns] 10ms 경과. 시뮬레이션 종료.", $time);
        $stop;
    end

endmodule