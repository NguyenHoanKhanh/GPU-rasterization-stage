`ifndef TILE_EVALUATOR_V
`define TILE_EVALUATOR_V
`timescale 1ns/1ps

module tile_evaluator #(
    parameter T = 16,
    parameter COORD_W = 10
) (
    input clk, rst, start,
    input generate_tile,
    input [COORD_W-1:0] min_x, min_y, max_x, max_y,
    output reg valid,
    output reg [COORD_W-1:0] tile_x, tile_y,
    output reg done
);
    reg [2:0] PState, NState;
    parameter IDLE = 3'd0, GENERATE_ = 3'd1, INCR_X = 3'd2, FINISH = 3'd3;
    reg [COORD_W-1:0] x_reg, y_reg;
    reg [COORD_W-1:0] temp_x, temp_y;
    
    // Combinational signals for next values
    reg next_valid;
    reg [COORD_W-1:0] next_tile_x, next_tile_y;
    reg next_done;
    reg [COORD_W-1:0] next_temp_x, next_temp_y;

    // Sequential block: Assign outputs and registers
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid <= 0;
            tile_x <= 0;
            tile_y <= 0;
            done <= 0;
            x_reg <= 0;
            y_reg <= 0;
            temp_x <= 0;
            temp_y <= 0;
            PState <= IDLE;
        end
        else if (start) begin
            PState <= NState;
            valid <= next_valid;
            tile_x <= next_tile_x;
            tile_y <= next_tile_y;
            done <= next_done;
            temp_x <= next_temp_x; // Update temp_x sequentially
            temp_y <= next_temp_y; // Update temp_y sequentially
            // Update registers based on state
            case (NState)
                IDLE: begin
                    x_reg <= min_x;
                    y_reg <= min_y;
                end
                INCR_X: begin
                    if (temp_x <= max_x) begin
                        x_reg <= temp_x;
                    end
                    else begin
                        x_reg <= min_x;
                        y_reg <= y_reg + T[COORD_W-1:0]; // Explicit bit-width
                    end
                end
            endcase
        end
        else begin
            PState <= IDLE;
            valid <= 0;
            tile_x <= 0;
            tile_y <= 0;
            done <= 0;
            temp_x <= 0;
            temp_y <= 0;
        end
    end

    // Combinational block: Compute next values
    always @(*) begin
        // Default values
        next_valid = 0;
        next_tile_x = tile_x;
        next_tile_y = tile_y;
        next_done = 0;
        next_temp_x = x_reg + T[COORD_W-1:0]; // Compute next value for temp_x
        next_temp_y = y_reg + T[COORD_W-1:0]; // Compute next value for temp_y
        NState = PState;

        case (PState)
            IDLE: begin
                NState = (start && generate_tile) ? GENERATE_ : IDLE;
            end
            GENERATE_: begin
                if (x_reg <= max_x && y_reg <= max_y) begin
                    next_valid = 1;
                    next_tile_x = x_reg;
                    next_tile_y = y_reg;
                    NState = INCR_X;
                end
                else begin
                    NState = FINISH;
                end
            end
            INCR_X: begin
                if (next_temp_x <= max_x) begin
                    NState = GENERATE_;
                end
                else begin
                    NState = GENERATE_;
                end
            end
            FINISH: begin
                next_done = 1;
                NState = IDLE;
            end
            default: begin
                NState = IDLE;
            end
        endcase
    end
endmodule

`endif