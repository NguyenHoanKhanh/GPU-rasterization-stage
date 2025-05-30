`ifndef PRIMITIVE_ASSEMBLY_V
`define PRIMITIVE_ASSEMBLY_V

module primitive_assembly (
    input clk, 
    input rst,
    input valid_in,
    input [31 : 0] vertex_x, vertex_y, vertex_z, vertex_w,
    output ready_out,
    output reg valid_out,
    output reg [31 : 0] x0, y0, z0, w0, 
    output reg [31 : 0] x1, y1, z1, w1,
    output reg [31 : 0] x2, y2, z2, w2
);
    reg [1 : 0] vertex_counter;
    assign ready_out = (vertex_counter != 2) || !valid_in;
    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            vertex_counter <= 0;
            valid_out <= 0;
        end
        else begin
            valid_out <= 0;
            if (valid_in && ready_out) begin
                case (vertex_counter)
                    0 : begin
                        x0 <= vertex_x;
                        y0 <= vertex_y;
                        z0 <= vertex_z;
                        w0 <= vertex_w;
                        vertex_counter <= 1;
                    end
                    1 : begin
                        x1 <= vertex_x;
                        y1 <= vertex_y;
                        z1 <= vertex_z;
                        w1 <= vertex_w;
                        vertex_counter <= 2;
                    end
                    2 : begin
                        x2 <= vertex_x;
                        y2 <= vertex_y;
                        z2 <= vertex_z;
                        w2 <= vertex_w;
                        valid_out <= 1;

                        vertex_counter <= 0;
                    end
                endcase 
            end
        end
    end
endmodule
`endif