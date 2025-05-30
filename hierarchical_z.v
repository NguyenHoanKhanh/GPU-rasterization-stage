`ifndef HIERARCHICAL_Z_V
`define HIERARCHICAL_Z_V
module hierarchical_z #(
    parameter COORD_W = 10, 
    parameter DEPTH_W = 32, 
    parameter SCREEN_H = 32, 
    parameter SCREEN_W = 32, 
    parameter MIP_LEVELS = 4
) (
    input clk, rst,
    input valid_in,
    input hiz_enable,
    input [COORD_W - 1 : 0] frag_x, frag_y,
    input [DEPTH_W - 1 : 0] frag_z,
    output reg valid_out,
    output reg [COORD_W - 1 : 0] frag_x_out, frag_y_out,
    output reg [DEPTH_W - 1 : 0] frag_z_out,
    output reg depth_write,
    output reg hiz_update
);
    reg [DEPTH_W - 1 : 0] depth_buffer [SCREEN_H - 1 : 0][SCREEN_W - 1 : 0];
    reg [DEPTH_W - 1 : 0] hiz_buffer [MIP_LEVELS - 1 : 0][SCREEN_H - 1 : 0][SCREEN_W - 1 : 0];
    reg [2 : 0] mip_level;
    reg [COORD_W - 1 : 0] min_x, min_y;

    reg [DEPTH_W - 1 : 0] depth_value, hiz_value;

    reg [2 : 0] PState, NState; // Extended to accommodate INIT state
    parameter INIT = 3'd0, IDLE = 3'd1, HIZ_TEST = 3'd2, DEPTH_TEST = 3'd3, UPDATE = 3'd4;

    // Registers for initialization
    reg [5 : 0] init_i, init_j; // SCREEN_H, SCREEN_W = 32, so 6 bits
    reg [1 : 0] init_k; // MIP_LEVELS = 4, so 2 bits

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            PState <= INIT;
            valid_out <= 0;
            depth_write <= 0;
            hiz_update <= 0;
            frag_x_out <= 0;
            frag_y_out <= 0;
            frag_z_out <= 0;
            init_i <= 0;
            init_j <= 0;
            init_k <= 0;
        end
        else begin
            PState <= NState;
            case (PState)
                INIT: begin
                    if (init_k < MIP_LEVELS) begin
                        if (init_i < SCREEN_H / (2**init_k)) begin
                            if (init_j < SCREEN_W / (2**init_k)) begin
                                hiz_buffer[init_k][init_i][init_j] <= {DEPTH_W{1'b1}};
                                if (init_k == 0) begin // Only initialize depth_buffer once
                                    depth_buffer[init_i][init_j] <= {DEPTH_W{1'b1}};
                                end
                                init_j <= init_j + 1;
                            end
                            else begin
                                init_j <= 0;
                                init_i <= init_i + 1;
                            end
                        end
                        else begin
                            init_i <= 0;
                            init_k <= init_k + 1;
                        end
                    end
                    else begin
                        init_i <= 0;
                        init_j <= 0;
                        init_k <= 0;
                        NState <= IDLE;
                    end
                end
                IDLE: begin
                    valid_out <= 0;
                    depth_write <= 0;
                    hiz_update <= 0;
                    init_i <= 0;
                    init_j <= 0;
                    init_k <= 0;
                end
                HIZ_TEST: begin
                    valid_out <= 0;
                    depth_write <= 0;
                    hiz_update <= 0;
                    frag_x_out <= frag_x;
                    frag_y_out <= frag_y;
                    frag_z_out <= frag_z;
                    init_i <= 0;
                    init_j <= 0;
                    init_k <= 0;
                end
                DEPTH_TEST: begin
                    valid_out <= 0;
                    depth_write <= 0;
                    hiz_update <= 0;
                    frag_x_out <= frag_x;
                    frag_y_out <= frag_y;
                    frag_z_out <= frag_z;
                    init_i <= 0;
                    init_j <= 0;
                    init_k <= 0;
                end
                UPDATE: begin
                    valid_out <= 1;
                    depth_write <= 1;
                    hiz_update <= 1;
                    frag_x_out <= frag_x;
                    frag_y_out <= frag_y;
                    frag_z_out <= frag_z;
                    depth_buffer[frag_y][frag_x] <= frag_z;
                    hiz_buffer[mip_level][min_y][min_x] <= frag_z;
                    init_i <= 0;
                    init_j <= 0;
                    init_k <= 0;
                end
                default: begin
                    valid_out <= 0;
                    depth_write <= 0;
                    hiz_update <= 0;
                    init_i <= 0;
                    init_j <= 0;
                    init_k <= 0;
                end
            endcase
        end
    end

    always @(*) begin
        mip_level = 0;
        min_x = frag_x;
        min_y = frag_y;
        hiz_value = {DEPTH_W{1'b1}};
        depth_value = depth_buffer[frag_y][frag_x];
        NState = PState;
        case (PState)
            IDLE: begin
                if (valid_in && hiz_enable) begin
                    NState = HIZ_TEST;
                end 
            end
            HIZ_TEST: begin
                mip_level = 2;
                min_x = frag_x >> mip_level;
                min_y = frag_y >> mip_level;
                hiz_value = hiz_buffer[mip_level][min_y][min_x];
                if (frag_z <= hiz_value) begin
                    NState = DEPTH_TEST;    
                end
                else begin
                    NState = IDLE;
                end
            end
            DEPTH_TEST: begin
                if (frag_z < depth_value) begin
                    NState = UPDATE;
                end
                else begin
                    NState = IDLE;
                end
            end
            UPDATE: begin
                NState = IDLE;
            end
            default: begin
                NState = IDLE;
            end
        endcase 
    end
endmodule
`endif