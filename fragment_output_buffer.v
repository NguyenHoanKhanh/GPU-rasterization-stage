`ifndef FRAGMENT_OUTPUT_BUFFER_V
`define FRAGMENT_OUTPUT_BUFFER_V
`timescale 1ns/1ps

module fragment_output_buffer #(
    parameter COORD_W = 10,       // Độ rộng tọa độ (x, y)
    parameter DEPTH_W = 32,       // Độ rộng độ sâu (z)
    parameter FIFO_DEPTH = 16,     // Độ sâu FIFO
    parameter FIFO_ADDR_W = $clog2(FIFO_DEPTH)  // Độ rộng địa chỉ FIFO
) (
    input clk, rst,               // Đồng hồ và reset
    input valid_in,               // Tín hiệu fragment hợp lệ từ attribute_interpolator
    input [COORD_W-1:0] fragment_x_in,  // Tọa độ x của fragment
    input [COORD_W-1:0] fragment_y_in,  // Tọa độ y của fragment
    input [DEPTH_W-1:0] fragment_z_in,  // Độ sâu của fragment
    input ready_in,               // Tín hiệu sẵn sàng từ module tiếp theo
    output reg ready_out,         // Tín hiệu sẵn sàng nhận fragment mới
    output reg valid_out_buffer,  // Tín hiệu fragment hợp lệ tại đầu ra
    output reg [COORD_W-1:0] fragment_x_out,  // Tọa độ x của fragment tại đầu ra
    output reg [COORD_W-1:0] fragment_y_out,  // Tọa độ y của fragment tại đầu ra
    output reg [DEPTH_W-1:0] fragment_z_out   // Độ sâu của fragment tại đầu ra
);
	integer i;
    // Bộ nhớ FIFO lưu trữ fragment (x, y, z)
    reg [COORD_W + COORD_W + DEPTH_W - 1:0] fifo_mem [FIFO_DEPTH-1:0];
    reg [FIFO_ADDR_W-1:0] wr_addr, rd_addr;  // Địa chỉ ghi và đọc
    reg [FIFO_ADDR_W:0] count;               // Đếm số phần tử trong FIFO

    // Tín hiệu FIFO đầy và rỗng
    wire fifo_empty = (count == 0);
    wire fifo_full = (count == FIFO_DEPTH);
    wire fifo_write = valid_in && !fifo_full;   // Ghi khi có fragment hợp lệ và FIFO không đầy
    wire fifo_read = ready_in && !fifo_empty;   // Đọc khi module tiếp theo sẵn sàng và FIFO không rỗng

    // Logic sẵn sàng nhận fragment mới
    always @(*) begin
        ready_out = !fifo_full;
    end

    // Logic đọc/ghi FIFO
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            wr_addr <= 0;
            rd_addr <= 0;
            count <= 0;
            valid_out_buffer <= 0;
            fragment_x_out <= 0;
            fragment_y_out <= 0;
            fragment_z_out <= 0;
            // Khởi tạo bộ nhớ FIFO
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                fifo_mem[i] <= 0;
            end
        end
        else begin
            // Chỉ ghi
            if (fifo_write && !fifo_read) begin
                fifo_mem[wr_addr] <= {fragment_x_in, fragment_y_in, fragment_z_in};
                wr_addr <= (wr_addr == FIFO_DEPTH-1) ? 0 : wr_addr + 1;
                count <= count + 1;
            end
            // Chỉ đọc
            else if (!fifo_write && fifo_read) begin
                {fragment_x_out, fragment_y_out, fragment_z_out} <= fifo_mem[rd_addr];
                rd_addr <= (rd_addr == FIFO_DEPTH-1) ? 0 : rd_addr + 1;
                count <= count - 1;
                valid_out_buffer <= 1;
            end
            // Ghi và đọc đồng thời
            else if (fifo_write && fifo_read) begin
                fifo_mem[wr_addr] <= {fragment_x_in, fragment_y_in, fragment_z_in};
                wr_addr <= (wr_addr == FIFO_DEPTH-1) ? 0 : wr_addr + 1;
                {fragment_x_out, fragment_y_out, fragment_z_out} <= fifo_mem[rd_addr];
                rd_addr <= (rd_addr == FIFO_DEPTH-1) ? 0 : rd_addr + 1;
                count <= count;
                valid_out_buffer <= 1;
            end
            // Không đọc, không ghi
            else begin
                valid_out_buffer <= 0;
            end
        end
    end

endmodule

`endif