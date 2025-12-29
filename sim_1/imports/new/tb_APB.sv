`timescale 1ns / 1ps

// version 4

interface apb_master_if (
    input logic clk,
    input logic reset
);
    logic        transfer;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        ready;
endinterface  //apb_master_if

class apbsignal;  //apb 시그널을 주고 받는 역할의 전문가

    logic                        transfer;
    logic                        write;
    rand logic            [31:0] addr;      // 제약해주지 않으면 원치않는 주소 출력
    rand logic            [31:0] wdata;

    // 32'h1000_0000 ~ 32'h1000_000C 사이의 값으로 rand 출력 제약 설정
    constraint c_addr { 
         addr inside {
            [32'h1000_0000:32'h1000_000C], 
            [32'h1000_1000:32'h1000_100C],
            [32'h1000_2000:32'h1000_200C], 
            [32'h1000_3000:32'h1000_300C]
        };
        addr % 4 == 0;
    }

    virtual apb_master_if        master_if;

    function new(virtual apb_master_if master_if);
        this.master_if = master_if;
    endfunction

    // Write to prpr Task
    task automatic send();
        master_if.transfer <= 1'b1;
        master_if.write    <= 1'b1;
        master_if.addr     <= this.addr;
        master_if.wdata    <= this.wdata;
        @(posedge master_if.clk);  // task에서 시간제어(@) 가능
        master_if.transfer <= 1'b0;  // function에서 시간제어 불가능
        
        wait (master_if.ready);
        @(posedge master_if.clk);
    endtask

    // Read from prpr Task
    task automatic receive();
        master_if.transfer <= 1'b1;
        master_if.write    <= 1'b0;
        master_if.addr     <= this.addr;
        @(posedge master_if.clk);  // task에서 시간제어(@) 가능, function에서 시간제어 불가능
        master_if.transfer <= 1'b0;
        
        wait (master_if.ready);
        @(posedge master_if.clk);
    endtask

endclass


module tb_APB ();

    // global signals
    logic        PCLK;
    logic        PRESET;

    // APB Interface Signals      
    logic [ 3:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;

    // APB Interface Signals
    logic        PSEL0;
    logic        PSEL1;
    logic        PSEL2;
    logic        PSEL3;
    logic [31:0] PRDATA0;
    logic [31:0] PRDATA1;
    logic [31:0] PRDATA2;
    logic [31:0] PRDATA3;
    logic        PREADY0;
    logic        PREADY1;
    logic        PREADY2;
    logic        PREADY3;

    apb_master_if master_if (
        PCLK,
        PRESET
    );  // 실제 하드웨어 생성하면서 동시에 PCLK, PRESET을 Interface에 Input

    apbsignal apb_verifi;  // handler


    APB_Manager dut_manager (
        .*,
        .transfer(master_if.transfer),
        .write   (master_if.write),
        .addr    (master_if.addr),
        .wdata   (master_if.wdata),
        .rdata   (master_if.rdata),
        .ready   (master_if.ready)
    );

    APB_Slave dut_slave0 (
        .*,
        .PSEL  (PSEL0),
        .PRDATA(PRDATA0),
        .PREADY(PREADY0)
    );

    APB_Slave dut_slave1 (
        .*,
        .PSEL  (PSEL1),
        .PRDATA(PRDATA1),
        .PREADY(PREADY1)
    );

    APB_Slave dut_slave2 (
        .*,
        .PSEL  (PSEL2),
        .PRDATA(PRDATA2),
        .PREADY(PREADY2)
    );

    APB_Slave dut_slave3 (
        .*,
        .PSEL  (PSEL3),
        .PRDATA(PRDATA3),
        .PREADY(PREADY3)
    );



    always #5 PCLK = ~PCLK;

    initial begin
        #00 PCLK = 0;
            PRESET = 1;
        #10 PRESET = 0;
    end

    initial begin
    // 1. 테스트할 모든 주소를 담을 큐(queue)를 선언합니다.
        logic [31:0] addr_queue[$];
        logic [31:0] temp_addr;
        int          rand_idx;

        apb_verifi  = new(master_if);

    // 2. 큐에 16개의 유효한 주소를 모두 추가합니다.
    // 각 슬레이브(0, 1, 2, 3)는 4개의 주소를 가집니다.
        for (int i = 0; i < 4; i++) begin
        addr_queue.push_back(32'h1000_0000 + i*32'h1000 + 32'h0);
        addr_queue.push_back(32'h1000_0000 + i*32'h1000 + 32'h4);
        addr_queue.push_back(32'h1000_0000 + i*32'h1000 + 32'h8);
        addr_queue.push_back(32'h1000_0000 + i*32'h1000 + 32'hC);
    end

    // 3. 주소 큐의 순서를 수동으로 무작위로 섞습니다. (피셔-예이츠 알고리즘)
    for (int i = addr_queue.size() - 1; i > 0; i--) begin
        // 0부터 i까지의 인덱스 중 하나를 무작위로 선택
        rand_idx = $urandom_range(i);
        
        // 현재 인덱스(i)의 값과 무작위 인덱스(rand_idx)의 값을 교환(swap)
        temp_addr = addr_queue[i];
        addr_queue[i] = addr_queue[rand_idx];
        addr_queue[rand_idx] = temp_addr;
    end

        repeat (3) @(posedge PCLK);

    // 4. 섞인 큐의 모든 주소에 대해 순차적으로 트랜잭션을 수행합니다.
    // foreach 루프를 사용하여 중복 없이 모든 주소를 한 번씩 사용합니다.
    foreach (addr_queue[i]) begin
      // wdata 값은 매번 랜덤하게 생성합니다.
      assert(apb_verifi.randomize());

    // 큐에서 꺼내온 고유 주소를 할당합니다.
    apb_verifi.addr = addr_queue[i];

    // 해당 주소에 쓰기 및 읽기 동작을 수행합니다.
    apb_verifi.send();
    apb_verifi.receive();
    end

    @(posedge PCLK);
    #30;
    $finish;
    end 
endmodule
