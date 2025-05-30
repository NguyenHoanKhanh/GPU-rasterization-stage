`ifndef DEPTH_STENCIL_TEST_V
`define DEPTH_STENCIL_TEST_V

module depth_stencil_test #(
    parameter COORD_W = 10,
    parameter DEPTH_W = 32,
    parameter STENCIL_W = 8,
    parameter SCREEN_W = 16,
    parameter SCREEN_H = 16
) (
    input wire clk, rst,
    input wire valid_in,
    input wire depth_enable, stencil_enable,
    input wire [COORD_W-1:0] frag_x, frag_y,
    input wire [DEPTH_W-1:0] frag_z,
    input wire [STENCIL_W-1:0] stencil_ref, stencil_mask,
    input wire [2:0] stencil_func, // GL_NEVER, GL_LESS, GL_EQUAL, GL_LEQUAL, GL_GREATER, GL_NOTEQUAL, GL_GEQUAL, GL_ALWAYS
    input wire [2:0] stencil_sfail, stencil_dpfail, stencil_dppass, // GL_KEEP, GL_ZERO, GL_REPLACE, GL_INCR, GL_DECR, GL_INVERT
    input wire [2:0] depth_func, // GL_LESS, GL_EQUAL, GL_LEQUAL, GL_GREATER, GL_NOTEQUAL, GL_GEQUAL, GL_ALWAYS
    output reg valid_out,
    output reg [COORD_W-1:0] frag_x_out, frag_y_out,
    output reg [DEPTH_W-1:0] frag_z_out,
    output reg depth_write,
    output reg stencil_write
);
    // Depth buffer và stencil buffer
    reg [DEPTH_W-1:0] depth_buffer [0:SCREEN_H-1][0:SCREEN_W-1];
    reg [STENCIL_W-1:0] stencil_buffer [0:SCREEN_H-1][0:SCREEN_W-1];
    
    // Giá trị từ buffer
    reg [DEPTH_W-1:0] depth_value;
    reg [STENCIL_W-1:0] stencil_value;
    
    // Kết quả kiểm tra
    wire stencil_pass;
    wire depth_pass;
    reg [STENCIL_W-1:0] new_stencil_value;
    
    integer i, j;
    initial begin
        for (i = 0; i < SCREEN_H; i = i + 1) begin
            for (j = 0; j < SCREEN_W; j = j + 1) begin
                depth_buffer[i][j] = {DEPTH_W{1'b1}};
                stencil_buffer[i][j] = 0;
            end
        end
    end

    assign stencil_pass = (!stencil_enable) ? 1'b1 :
                        (stencil_func == 3'd0) ? 1'b0 : // GL_NEVER
                        (stencil_func == 3'd1) ? ((stencil_ref & stencil_mask) < (stencil_value & stencil_mask)) : // GL_LESS
                        (stencil_func == 3'd2) ? ((stencil_ref & stencil_mask) == (stencil_value & stencil_mask)) : // GL_EQUAL
                        (stencil_func == 3'd3) ? ((stencil_ref & stencil_mask) <= (stencil_value & stencil_mask)) : // GL_LEQUAL
                        (stencil_func == 3'd4) ? ((stencil_ref & stencil_mask) > (stencil_value & stencil_mask)) : // GL_GREATER
                        (stencil_func == 3'd5) ? ((stencil_ref & stencil_mask) != (stencil_value & stencil_mask)) : // GL_NOTEQUAL
                        (stencil_func == 3'd6) ? ((stencil_ref & stencil_mask) >= (stencil_value & stencil_mask)) : // GL_GEQUAL
                        1'b1;// GL_ALWAYS
    // Depth Test
    assign depth_pass = (!depth_enable) ? 1'b1 :
                       (depth_func == 3'd1) ? (frag_z < depth_value) : // GL_LESS
                       (depth_func == 3'd2) ? (frag_z == depth_value) : // GL_EQUAL
                       (depth_func == 3'd3) ? (frag_z <= depth_value) : // GL_LEQUAL
                       (depth_func == 3'd4) ? (frag_z > depth_value) : // GL_GREATER
                       (depth_func == 3'd5) ? (frag_z != depth_value) : // GL_NOTEQUAL
                       (depth_func == 3'd6) ? (frag_z >= depth_value) : // GL_GEQUAL
                       1'b1; // GL_ALWAYS

    // Logic cập nhật stencil buffer
    always @(*) begin
        new_stencil_value = stencil_value;
        if (!stencil_enable) begin
            new_stencil_value = stencil_value;
        end
        else if (!stencil_pass) begin
            case (stencil_sfail)
                3'd0: new_stencil_value = stencil_value; // GL_KEEP
                3'd1: new_stencil_value = 0; // GL_ZERO
                3'd2: new_stencil_value = stencil_ref; // GL_REPLACE
                3'd3: new_stencil_value = (stencil_value == {STENCIL_W{1'b1}}) ? stencil_value : stencil_value + 1; // GL_INCR
                3'd4: new_stencil_value = (stencil_value == 0) ? 0 : stencil_value - 1; // GL_DECR
                3'd5: new_stencil_value = ~stencil_value; // GL_INVERT
                default: new_stencil_value = stencil_value;
            endcase
        end
        else if (!depth_pass) begin
            case (stencil_dpfail)
                3'd0: new_stencil_value = stencil_value; // GL_KEEP
                3'd1: new_stencil_value = 0; // GL_ZERO
                3'd2: new_stencil_value = stencil_ref; // GL_REPLACE
                3'd3: new_stencil_value = (stencil_value == {STENCIL_W{1'b1}}) ? stencil_value : stencil_value + 1; // GL_INCR
                3'd4: new_stencil_value = (stencil_value == 0) ? 0 : stencil_value - 1; // GL_DECR
                3'd5: new_stencil_value = ~stencil_value; // GL_INVERT
                default: new_stencil_value = stencil_value;
            endcase
        end
        else begin
            case (stencil_dppass)
                3'd0: new_stencil_value = stencil_value; // GL_KEEP
                3'd1: new_stencil_value = 0; // GL_ZERO
                3'd2: new_stencil_value = stencil_ref; // GL_REPLACE
                3'd3: new_stencil_value = (stencil_value == {STENCIL_W{1'b1}}) ? stencil_value : stencil_value + 1; // GL_INCR
                3'd4: new_stencil_value = (stencil_value == 0) ? 0 : stencil_value - 1; // GL_DECR
                3'd5: new_stencil_value = ~stencil_value; // GL_INVERT
                default: new_stencil_value = stencil_value;
            endcase
        end
    end

    // Logic xử lý và cập nhật
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= 0;
            depth_write <= 0;
            stencil_write <= 0;
            frag_x_out <= 0;
            frag_y_out <= 0;
            frag_z_out <= 0;
        end
        else begin
            depth_value = depth_buffer[frag_y][frag_x];
            stencil_value = stencil_buffer[frag_y][frag_x];
            
            valid_out <= 0;
            depth_write <= 0;
            stencil_write <= 0;
            
            if (valid_in) begin
                frag_x_out <= frag_x;
                frag_y_out <= frag_y;
                frag_z_out <= frag_z;
                
                if (stencil_pass && depth_pass) begin
                    valid_out <= 1;
                    depth_write <= depth_enable;
                    stencil_write <= stencil_enable;
                end
                else if (stencil_enable) begin
                    stencil_write <= 1; // Cập nhật stencil ngay cả khi thất bại
                end
                
                // Cập nhật buffer
                if (depth_write) begin
                    depth_buffer[frag_y][frag_x] <= frag_z;
                end
                if (stencil_write) begin
                    stencil_buffer[frag_y][frag_x] <= new_stencil_value;
                end
            end
        end
    end

endmodule

`endif