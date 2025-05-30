`ifndef FRAGMENT_EMITTER_V_V
`define FRAGMENT_EMITTER_V

module fragment_emitter #(
    parameter COORD_W = 10,
    parameter COEFF_W = 16,
    parameter T = 16
)(
    input clk, rst,
    input valid_in,
    input [COORD_W - 1 : 0] tile_x, tile_y,
    input tile_inside,
    input [2 * COEFF_W - 1 : 0] e0, e1, e2,
    input [COEFF_W - 1 : 0] a0, a1, a2,
    output reg valid_out,
    output reg [COORD_W - 1 : 0] frag_x, frag_y,
    output reg done_out
);

    reg [2 : 0] PState, NState;
    parameter IDLE = 3'd0, INIT_TILE = 3'd1, CHECK_PIXEL = 3'd2, OUTPUT_FRAGMENT = 3'd3, FINISH_TILE = 3'd4;

    reg [COORD_W - 1 : 0] pixel_x, pixel_y;
    reg [COORD_W - 1 : 0] next_pixel_x, next_pixel_y;
    reg [2 * COEFF_W - 1 : 0] curr_e0, curr_e1, curr_e2;
    
    // Combinational signals for next edge values
    reg [2 * COEFF_W - 1 : 0] next_e0, next_e1, next_e2;

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            PState <= IDLE;
            valid_out <= 0;
            done_out <= 0;
            frag_x <= 0;
            frag_y <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
            curr_e0 <= 0;
            curr_e1 <= 0;
            curr_e2 <= 0;
        end
        else begin
            PState <= NState;
            pixel_x <= next_pixel_x;
            pixel_y <= next_pixel_y;
            curr_e0 <= next_e0; // Update sequentially
            curr_e1 <= next_e1;
            curr_e2 <= next_e2;
            
            if (NState == OUTPUT_FRAGMENT) begin
                frag_x <= pixel_x;
                frag_y <= pixel_y;
                valid_out <= 1;
            end
            else begin
                valid_out <= 0;
            end

            if (NState == FINISH_TILE) begin
                done_out <= 1;
            end
            else begin 
                done_out <= 0;
            end
        end
    end

    always @(*) begin
        NState = PState;
        next_pixel_x = pixel_x;
        next_pixel_y = pixel_y;
        next_e0 = curr_e0; // Default: hold current value
        next_e1 = curr_e1;
        next_e2 = curr_e2;

        case (PState)
            IDLE: begin
                if (valid_in && tile_inside) begin
                    NState = INIT_TILE;
                end
            end
            INIT_TILE: begin
                next_pixel_x = tile_x;
                next_pixel_y = tile_y;
                next_e0 = e0; // Initialize edge values
                next_e1 = e1;
                next_e2 = e2;
                NState = CHECK_PIXEL;
            end
            CHECK_PIXEL: begin
                if (curr_e0 >= 0 && curr_e1 >= 0 && curr_e2 >= 0) begin
                    NState = OUTPUT_FRAGMENT; // Pixel lies within triangle
                end
                else begin
                    // Move to next pixel
                    if (pixel_x < tile_x + T[COORD_W-1:0] - 1) begin
                        next_pixel_x = pixel_x + 1;
                        next_e0 = next_pixel_x == tile_x ? e0 : curr_e0 + a0;
                        next_e1 = next_pixel_x == tile_x ? e1 : curr_e1 + a1;
                        next_e2 = next_pixel_x == tile_x ? e2 : curr_e2 + a2;
                        NState = CHECK_PIXEL;
                    end
                    else if (pixel_y < tile_y + T[COORD_W-1:0] - 1) begin
                        next_pixel_x = tile_x;
                        next_pixel_y = pixel_y + 1;
                        next_e0 = e0; // Reset edge values
                        next_e1 = e1;
                        next_e2 = e2;
                        NState = CHECK_PIXEL;
                    end
                    else begin
                        NState = FINISH_TILE;
                    end
                end
            end
            OUTPUT_FRAGMENT: begin
                if (pixel_x < tile_x + T[COORD_W-1:0] - 1) begin
                    next_pixel_x = pixel_x + 1;
                    next_e0 = next_pixel_x == tile_x ? e0 : curr_e0 + a0;
                    next_e1 = next_pixel_x == tile_x ? e1 : curr_e1 + a1;
                    next_e2 = next_pixel_x == tile_x ? e2 : curr_e2 + a2;
                    NState = CHECK_PIXEL;
                end
                else if (pixel_y < tile_y + T[COORD_W-1:0] - 1) begin
                    next_pixel_x = tile_x;
                    next_pixel_y = pixel_y + 1;
                    next_e0 = e0; // Reset edge values
                    next_e1 = e1;
                    next_e2 = e2;
                    NState = CHECK_PIXEL;
                end
                else begin
                    NState = FINISH_TILE;
                end
            end
            FINISH_TILE: begin
                NState = IDLE;
            end
            default: begin
                NState = IDLE;
            end
        endcase
    end
endmodule
`endif