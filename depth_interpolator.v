`ifndef DEPTH_INTERPOLATOR_V
`define DEPTH_INTERPOLATOR_V

module depth_interpolator #(
    parameter COORD_W = 10,
    parameter DEPTH_W = 32
) (
    input clk, rst,
    input valid_in,
    input [COORD_W - 1 : 0] frag_x, frag_y,
    input [COORD_W - 1 : 0] x0, y0, x1, y1, x2, y2,
    input [DEPTH_W - 1 : 0] z0, z1, z2,
    input [2 * DEPTH_W - 1 : 0] denom,
    output reg valid_out,
    output reg [COORD_W - 1 : 0] out_frag_x, out_frag_y,
    output reg [DEPTH_W - 1 : 0] frag_z
);  
    reg [2 : 0] PState, NState;
    parameter IDLE = 2'd0, COMPUTE = 2'd1, OUTPUT = 2'd2;
    reg [2 * DEPTH_W - 1 : 0] w0, w1, w2;
    reg [2 * DEPTH_W - 1 : 0] temp_z;

    // FSM: Cập nhật trạng thái và đầu ra
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            PState <= IDLE;
            valid_out <= 0;
            out_frag_x <= 0;
            out_frag_y <= 0;
            frag_z <= 0;
            w0 <= 0;
            w1 <= 0;
            w2 <= 0;
        end
        else begin
            PState <= NState;

            // Cập nhật đầu ra
            if (NState == OUTPUT) begin
                out_frag_x <= frag_x;
                out_frag_y <= frag_y;
                frag_z <= temp_z[DEPTH_W-1:0]; // Cắt ngắn để phù hợp DEPTH_W
                valid_out <= 1;
            end
            else begin
                valid_out <= 0;
            end
        end
    end

    // FSM: Logic chuyển trạng thái và tính toán
    always @(*) begin
        NState = PState;
        temp_z = 0;

        case (PState)
            IDLE: begin
                if (valid_in) begin
                    NState = COMPUTE;
                end
            end
            COMPUTE: begin
                // Tính trọng số barycentric
                w0 = ((y1 - y2) * (frag_x - x2) + (x2 - x1) * (frag_y - y2));
                w1 = ((y2 - y0) * (frag_x - x2) + (x0 - x2) * (frag_y - y2));
                w2 = denom - w0 - w1;

                // Nội suy độ sâu: z = (w0 * z0 + w1 * z1 + w2 * z2) / denom
                if (denom != 0) begin
                    temp_z = (w0 * z0 + w1 * z1 + w2 * z2) / denom;
                end
                else begin
                    temp_z = 0; // Xử lý trường hợp tam giác suy biến
                end

                NState = OUTPUT;
            end
            OUTPUT: begin
                NState = IDLE;
            end
            default: begin
                NState = IDLE;
            end
        endcase
    end
    
endmodule
`endif 