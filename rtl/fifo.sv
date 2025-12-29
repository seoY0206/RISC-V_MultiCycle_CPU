`timescale 1ns / 1ps

/*
 * 범용 동기식 FIFO 모듈 (BRAM 읽기 모델링 최종 버전)
 */
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
) (
    input  logic                  clk,
    input  logic                  rst, // Synchronous reset expected
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data, // Registered read data output
    output logic                  empty   // Registered empty output
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Use logic for memory array - preferred for synthesis tools
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0]   count;
    logic empty_comb;
    reg   empty_reg;

    // Registered output for read data to model BRAM latency
    reg   [DATA_WIDTH-1:0] rd_data_reg;

    assign full  = (count == DEPTH);
    assign empty_comb = (count == 0);
    assign empty = empty_reg;
    assign rd_data = rd_data_reg;   // Output registered value

    // Register for 'empty' signal
    always_ff @(posedge clk) begin // Synchronous reset
        if (rst) begin
            empty_reg <= 1'b1;
        end else begin
            empty_reg <= empty_comb;
        end
    end

    // --- BRAM Read Data Path ---
    // Read occurs combinationally based on rd_ptr into an intermediate signal
    logic [DATA_WIDTH-1:0] mem_read_data;
    assign mem_read_data = mem[rd_ptr];

    // Register the read data on the next clock edge
    always_ff @(posedge clk) begin // Synchronous reset
        if (rst) begin
            rd_data_reg <= '0;
        end else begin
             // Always update rd_data_reg with the value read in the previous cycle
             // based on the rd_ptr of the previous cycle.
             rd_data_reg <= mem_read_data;
             // Note: rd_en gating is removed here; output reflects mem[rd_ptr] delayed by 1 cycle.
             //       The rd_en signal is primarily used to advance the rd_ptr and count.
        end
    end

    // --- Pointer and Count Logic ---
    always_ff @(posedge clk) begin // Synchronous reset
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            // Write Operation (only if enabled and not full)
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data; // Write data
                wr_ptr      <= wr_ptr + 1; // Increment pointer for next write
            end

            // Read Operation - Pointer Update (only if enabled and not empty)
            if (rd_en && !empty_reg) begin // Use registered empty
                rd_ptr <= rd_ptr + 1; // Increment pointer for next read
            end

            // Count Operation (carefully considers simultaneous read/write)
            if (wr_en && !full && (!rd_en || empty_reg)) begin
                // Write only
                count <= count + 1;
            end else if (rd_en && !empty_reg && (!wr_en || full)) begin
                // Read only
                count <= count - 1;
            end else if (wr_en && !full && rd_en && !empty_reg) begin
                 // Write and Read simultaneously: count remains the same
                 count <= count;
            end
             // else: No change if neither write nor read validly occurs
        end
    end

endmodule



// `timescale 1ns / 1ps

// /*
//  * 범용 동기식 FIFO 모듈 (mem 타입을 reg로 변경)
//  */
// module fifo #(
//     parameter DATA_WIDTH = 8,
//     parameter DEPTH      = 16
// ) (
//     input  logic                  clk,
//     input  logic                  rst, // Synchronous reset expected
//     input  logic                  wr_en,
//     input  logic [DATA_WIDTH-1:0] wr_data,
//     output logic                  full,
//     input  logic                  rd_en,
//     output logic [DATA_WIDTH-1:0] rd_data,
//     output logic                  empty // Registered empty output
// );
//     localparam ADDR_WIDTH = $clog2(DEPTH);

//     // FIFO를 위한 메모리 (레지스터 배열) [Use reg for mem]
//     // logic [DATA_WIDTH-1:0] mem [0:DEPTH-1]; // [수정 전]
//     reg   [DATA_WIDTH-1:0] mem [0:DEPTH-1]; // [수정 후] Use traditional reg type

//     logic [ADDR_WIDTH-1:0] wr_ptr;
//     logic [ADDR_WIDTH-1:0] rd_ptr;
//     logic [ADDR_WIDTH:0]   count;
//     logic empty_comb;
//     reg   empty_reg;

//     assign full  = (count == DEPTH);
//     assign empty_comb = (count == 0);
//     assign empty = empty_reg;
//     assign rd_data = mem[rd_ptr]; // Combinational read remains the same

//     always_ff @(posedge clk) begin // Synchronous reset for empty_reg
//         if (rst) begin
//             empty_reg <= 1'b1;
//         end else begin
//             empty_reg <= empty_comb;
//         end
//     end

//     always_ff @(posedge clk) begin // Synchronous reset for pointers/count/mem write
//         if (rst) begin
//             wr_ptr <= '0;
//             rd_ptr <= '0;
//             count  <= '0;
//             // Optional: Initialize memory content on reset (usually not needed for BRAM)
//             // for (int i = 0; i < DEPTH; i++) begin
//             //     mem[i] <= '0;
//             // end
//         end else begin
//             if (wr_en && !full) begin
//                 mem[wr_ptr] <= wr_data; // Write uses reg array
//                 wr_ptr      <= wr_ptr + 1;
//             end
//             if (rd_en && !empty) begin
//                 rd_ptr <= rd_ptr + 1;
//             end
//             if (wr_en && !full && (!rd_en || empty)) begin
//                 count <= count + 1;
//             end else if (rd_en && !empty && (!wr_en || full)) begin
//                 count <= count - 1;
//             end else begin
//                 count <= count;
//             end
//         end
//     end

// endmodule

