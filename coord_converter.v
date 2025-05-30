`ifndef COORD_CONVERTER_V
`define COORD_CONVERTER_V

// Module coord_converter (đơn giản hóa để chuyển đổi tọa độ)
module coord_converter #(
    parameter INPUT_W = 32,
    parameter OUTPUT_W = 10
) (
    input clk, rst, valid_in,
    input [INPUT_W-1:0] in_min_x, in_min_y, in_max_x, in_max_y,
    input [INPUT_W-1:0] in_x0, in_y0, in_x1, in_y1, in_x2, in_y2,
    output reg [OUTPUT_W-1:0] out_min_x, out_min_y, out_max_x, out_max_y,
    output reg [OUTPUT_W-1:0] out_x0, out_y0, out_x1, out_y1, out_x2, out_y2
);
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            out_min_x <= 0; out_min_y <= 0; out_max_x <= 0; out_max_y <= 0;
            out_x0 <= 0; out_y0 <= 0; out_x1 <= 0; out_y1 <= 0; out_x2 <= 0; out_y2 <= 0;
        end
        else if (valid_in) begin
            out_min_x <= in_min_x[OUTPUT_W-1:0];
            out_min_y <= in_min_y[OUTPUT_W-1:0];
            out_max_x <= in_max_x[OUTPUT_W-1:0];
            out_max_y <= in_max_y[OUTPUT_W-1:0];
            out_x0 <= in_x0[OUTPUT_W-1:0];
            out_y0 <= in_y0[OUTPUT_W-1:0];
            out_x1 <= in_x1[OUTPUT_W-1:0];
            out_y1 <= in_y1[OUTPUT_W-1:0];
            out_x2 <= in_x2[OUTPUT_W-1:0];
            out_y2 <= in_y2[OUTPUT_W-1:0];
        end
    end
endmodule

`endif