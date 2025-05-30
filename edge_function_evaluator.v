`ifndef EDGE_FUNCTION_EVALUATOR_V
`define EDGE_FUNCTION_EVALUATOR_V

module edge_function_evaluator #(
    parameter COORD_W = 10,
    parameter COEFF_W = 16,
    parameter T = 16
)(
    input clk, rst,
    input valid_in,
    input [COEFF_W - 1 : 0] a0, b0, c0, a1, b1, c1, a2, b2, c2,
    input [COORD_W - 1 : 0] tile_x, tile_y,
    output reg valid_out,
    output reg tile_inside,
    output reg [31 : 0] e0, e1, e2
);
    wire [COORD_W - 1 : 0] x0, y0, x1, y1;
    assign x0 = tile_x;
    assign y0 = tile_y;
    assign x1 = tile_x + T - 1;
    assign y1 = tile_y + T - 1;

    reg [31 : 0] e0_x0y0, e1_x0y0, e2_x0y0;
    reg [31 : 0] e0_x1y0, e1_x1y0, e2_x1y0;
    reg [31 : 0] e0_x0y1, e1_x0y1, e2_x0y1;
    reg [31 : 0] e0_x1y1, e1_x1y1, e2_x1y1;

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            valid_out <= 0;
            tile_inside <= 0;
            e0 <= 0; e1 <= 0; e2 <= 0;
        end
        else begin
            if (valid_in) begin
                // Tính giá trị hàm cạnh tại bốn góc của tile
                    e0_x0y0 <= a0 * x0 + b0 * y0 + c0; 
                    e1_x0y0 <= a1 * x0 + b1 * y0 + c1;
                    e2_x0y0 <= a2 * x0 + b2 * y0 + c2;

                    e0_x1y0 <= a0 * x1 + b0 * y0 + c0;
                    e1_x1y0 <= a1 * x1 + b1 * y0 + c1;
                    e2_x1y0 <= a2 * x1 + b2 * y0 + c2;
                    
                    e0_x0y1 <= a0 * x0 + b0 * y1 + c0; 
                    e1_x0y1 <= a1 * x0 + b1 * y1 + c1;
                    e2_x0y1 <= a2 * x0 + b2 * y1 + c2;

                    e0_x1y1 <= a0 * x1 + b0 * y1 + c0; 
                    e1_x1y1 <= a1 * x1 + b1 * y1 + c1;
                    e2_x1y1 <= a2 * x1 + b2 * y1 + c2;

                //Tile có chứa hình khôngg
                    tile_inside <= (    (e0_x0y0 >= 0 && e1_x0y0 >= 0 && e2_x0y0 >= 0) ||
                                        (e0_x1y0 >= 0 && e1_x1y0 >= 0 && e2_x1y0 >= 0) ||
                                        (e0_x0y1 >= 0 && e1_x0y1 >= 0 && e2_x0y1 >= 0) ||
                                        (e0_x1y1 >= 0 && e1_x1y1 >= 0 && e2_x1y1 >= 0));

                    e0 <= e0_x0y0;
                    e1 <= e1_x0y0;
                    e2 <= e2_x0y0;

                    valid_out <= 1;
                end
            else begin
                valid_out <= 0;
                tile_inside <= 0;
            end
        end
    end
endmodule
`endif