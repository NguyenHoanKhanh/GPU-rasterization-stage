`ifndef ATTRIBUTE_INTERPOLATOR_V
`define ATTRIBUTE_INTERPOLATOR_V

module attribute_interpolator #(
    parameter COORD_W = 10,
    parameter DEPTH_W = 32 
) (
    input clk, rst,
    input valid_in,
    input [COORD_W - 1 : 0] frag_x, frag_y,
    input [DEPTH_W - 1 : 0] frag_z,
    output reg valid_out,
    output reg [COORD_W - 1 : 0] out_frag_x, out_frag_y,
    output reg [DEPTH_W - 1 : 0] out_frag_z
);
    // Định nghĩa các trạng thái của FSM
    reg [1:0] PState, NState;
    parameter IDLE = 2'd0, OUTPUT = 2'd1;

    // FSM: Cập nhật trạng thái
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            PState <= IDLE;
            valid_out <= 0;
            out_frag_x <= 0;
            out_frag_y <= 0;
            out_frag_z <= 0;
        end
        else begin
            PState <= NState;

            // Cập nhật đầu ra
            if (PState == OUTPUT) begin
                valid_out <= 1;
                out_frag_x <= frag_x;
                out_frag_y <= frag_y;
                out_frag_z <= frag_z;
            end
            else begin
                valid_out <= 0;
            end
        end
    end

    // FSM: Logic chuyển trạng thái
    always @(*) begin
        NState = PState;
        case (PState)
            IDLE: begin
                if (valid_in) begin
                    NState = OUTPUT;
                end
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