`ifndef TILE_TRAVERSER_V
`define TILE_TRAVERSER_V
module tile_traverser #(
    parameter COORD_W = 10
) (
    input clk, rst,
    input valid_in,
    input [COORD_W-1:0] tile_x, tile_y,
    input tile_inside,
    input done_in,
    input [COORD_W-1:0] min_x, min_y, max_x, max_y, // Added inputs
    output reg valid_out,
    output reg [COORD_W-1:0] tile_x_out, tile_y_out,
    output reg done_out
);
    // Internal state
    reg [COORD_W-1:0] current_x, current_y;
    reg [1:0] state;
    localparam IDLE = 2'd0, TRAVERSE = 2'd1, DONE = 2'd2;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= 0;
            tile_x_out <= 0;
            tile_y_out <= 0;
            done_out <= 0;
            current_x <= 0;
            current_y <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done_out <= 0;
                    if (valid_in && tile_inside) begin
                        state <= TRAVERSE;
                        current_x <= tile_x;
                        current_y <= tile_y;
                        valid_out <= 1;
                        tile_x_out <= tile_x;
                        tile_y_out <= tile_y;
                    end
                end
                TRAVERSE: begin
                    if (done_in) begin // tile_evaluator signals completion
                        state <= DONE;
                        valid_out <= 0;
                        done_out <= 1;
                    end else if (tile_inside) begin
                        valid_out <= 1;
                        tile_x_out <= current_x;
                        tile_y_out <= current_y;
                        // Advance to next tile
                        if (current_x < max_x) begin
                            current_x <= current_x + 1;
                        end else begin
                            current_x <= min_x;
                            current_y <= current_y + 1;
                        end
                        if (current_y >= max_y) begin
                            state <= DONE;
                            valid_out <= 0;
                            done_out <= 1;
                        end
                    end else begin
                        valid_out <= 0;
                        // Advance to next tile even if not inside
                        if (current_x < max_x) begin
                            current_x <= current_x + 1;
                        end else begin
                            current_x <= min_x;
                            current_y <= current_y + 1;
                        end
                        if (current_y >= max_y) begin
                            state <= DONE;
                            valid_out <= 0;
                            done_out <= 1;
                        end
                    end
                end
                DONE: begin
                    valid_out <= 0;
                    done_out <= 1;
                    if (!valid_in) begin
                        state <= IDLE;
                        done_out <= 0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`endif