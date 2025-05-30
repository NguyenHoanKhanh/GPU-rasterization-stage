`ifndef CLIPPING_V
`define CLIPPING_V

// Clipping block: Sutherland-Hodgman polygon clipping against view frustum.
module clipping_unit #(
    parameter COORD_W = 32,
    parameter MAX_VERTS = 16
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     valid_in,
    input  wire [COORD_W - 1 : 0]       v0_x, v0_y, v0_z, v0_w,
    input  wire [COORD_W - 1 : 0]       v1_x, v1_y, v1_z, v1_w,
    input  wire [COORD_W - 1 : 0]       v2_x, v2_y, v2_z, v2_w,

    output reg                      valid_out,
    output reg  [COORD_W - 1 : 0]       out_v0_x, out_v0_y, out_v0_z, out_v0_w,
    output reg  [COORD_W - 1 : 0]       out_v1_x, out_v1_y, out_v1_z, out_v1_w,
    output reg  [COORD_W - 1 : 0]       out_v2_x, out_v2_y, out_v2_z, out_v2_w,
    output reg  [2 : 0]               vertex_count
);
integer j;
// Frustum planes
localparam NEAR   = 3'd0;
localparam FAR    = 3'd1;
localparam LEFT   = 3'd2;
localparam RIGHT  = 3'd3;
localparam TOP    = 3'd4;
localparam BOTTOM = 3'd5;
localparam NUM_PLANE = 6;

// Working buffers (ping-pong)
reg [COORD_W - 1 : 0] buf_x[MAX_VERTS - 1 : 0];
reg [COORD_W - 1 : 0] buf_y[MAX_VERTS - 1 : 0];
reg [COORD_W - 1 : 0] buf_z[MAX_VERTS - 1 : 0];
reg [COORD_W - 1 : 0] buf_w[MAX_VERTS - 1 : 0];

reg [COORD_W-1:0] next_x[MAX_VERTS - 1 : 0];
reg [COORD_W-1:0] next_y[MAX_VERTS - 1 : 0];
reg [COORD_W-1:0] next_z[MAX_VERTS - 1 : 0];
reg [COORD_W-1:0] next_w[MAX_VERTS - 1 : 0];

// State machine
localparam S_IDLE   = 2'd0;
localparam S_CLIP   = 2'd1;
localparam S_OUTPUT = 2'd2;
reg inside1, inside2;
reg [1:0] state;
reg [2:0] plane;
reg [3:0] in_cnt, out_cnt;
integer i;

// Check inside
function is_inside;
    input [COORD_W-1:0] x,y,z,w;
    input [2:0] pid;
    begin
        case(pid)
            NEAR:   is_inside = (z >= -w);
            FAR:    is_inside = (z <=  w);
            LEFT:   is_inside = (x >= -w);
            RIGHT:  is_inside = (x <=  w);
            TOP:    is_inside = (y >= -w);
            BOTTOM: is_inside = (y <=  w);
            default:is_inside = 1'b1;
        endcase
    end
endfunction

// Intersect edge with plane
function [4*COORD_W-1:0] intersect;
    input [COORD_W-1:0] x1,y1,z1,w1, x2,y2,z2,w2;
    input [2:0] pid;
    reg [COORD_W-1:0] tnum, tden;
    reg [COORD_W-1:0] t;
    reg [COORD_W-1:0] xi,yi,zi,wi;
    begin
        // t = (plane - v1)/(v2-v1)
        case(pid)
            NEAR:   begin tnum = w1 + z1;      tden = (z2+ w2) - (z1+ w1); end
            FAR:    begin tnum = w1 - z1;      tden = (z2- w2) - (z1- w1); end
            LEFT:   begin tnum = w1 + x1;      tden = (x2+ w2) - (x1+ w1); end
            RIGHT:  begin tnum = w1 - x1;      tden = (x2- w2) - (x1- w1); end
            TOP:    begin tnum = w1 + y1;      tden = (y2+ w2) - (y1+ w1); end
            BOTTOM: begin tnum = w1 - y1;      tden = (y2- w2) - (y1- w1); end
            default: begin tnum=0; tden=1; end
        endcase
        t = tnum * ((tden!=0) ? ( {16{1'b1}} / tden ) : 0);
        xi = x1 + ((x2 - x1) * t) >> COORD_W;
        yi = y1 + ((y2 - y1) * t) >> COORD_W;
        zi = z1 + ((z2 - z1) * t) >> COORD_W;
        wi = w1 + ((w2 - w1) * t) >> COORD_W;
        intersect = {xi,yi,zi,wi};
    end
endfunction
reg [COORD_W - 1 : 0] xi, yi, zi, wi;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= S_IDLE;
        valid_out  <= 1'b0;
		  for (i = 0; i < MAX_VERTS; i = i + 1) begin
            buf_x[i] <= {COORD_W{1'b0}};
            buf_y[i] <= {COORD_W{1'b0}};
            buf_z[i] <= {COORD_W{1'b0}};
            buf_w[i] <= {COORD_W{1'b0}};
        end
    end else begin
        case(state)
            S_IDLE: if (valid_in) begin
                // load triangle
                buf_x[0]<=v0_x; buf_y[0]<=v0_y; buf_z[0]<=v0_z; buf_w[0]<=v0_w;
                buf_x[1]<=v1_x; buf_y[1]<=v1_y; buf_z[1]<=v1_z; buf_w[1]<=v1_w;
                buf_x[2]<=v2_x; buf_y[2]<=v2_y; buf_z[2]<=v2_z; buf_w[2]<=v2_w;
                in_cnt    <= 3;
                plane     <= NEAR;
                state     <= S_CLIP;
            end

            S_CLIP: begin
                out_cnt = 0;
                // Sutherland–Hodgman for each edge
                for (i=0; i<in_cnt && i < MAX_VERTS; i=i+1) begin
                    j = (i+1)%in_cnt;
                    inside1 = is_inside(buf_x[i],buf_y[i],buf_z[i],buf_w[i],plane);
                    inside2 = is_inside(buf_x[j],buf_y[j],buf_z[j],buf_w[j],plane);
                    if (inside1) begin
                        if (out_cnt < MAX_VERTS) begin
									next_x[out_cnt] = buf_x[i];
				               next_y[out_cnt] = buf_y[i];
									next_z[out_cnt] = buf_z[i];
				               next_w[out_cnt] = buf_w[i];
				               out_cnt = out_cnt + 1;
           					end
                        if (!inside2) begin
                            // leaving -> intersect
                            {xi,yi,zi,wi} = intersect(
                                buf_x[i], buf_y[i], buf_z[i], buf_w[i],
                                buf_x[j], buf_y[j], buf_z[j], buf_w[j], plane);
                            if (out_cnt < MAX_VERTS) begin
											next_x[out_cnt] = xi; next_y[out_cnt] = yi;
											next_z[out_cnt] = zi; next_w[out_cnt] = wi;
											out_cnt = out_cnt + 1;
									end
                        end
                    end else if (inside2) begin
                        // entering -> intersect + keep
                        {xi,yi,zi,wi} = intersect(
                            buf_x[i],buf_y[i],buf_z[i],buf_w[i],
                            buf_x[j],buf_y[j],buf_z[j],buf_w[j],plane);
                        if (out_cnt < MAX_VERTS) begin
									next_x[out_cnt] = xi; next_y[out_cnt] = yi;
									next_z[out_cnt] = zi; next_w[out_cnt] = wi;
									out_cnt = out_cnt + 1;
								end

                        if (out_cnt < MAX_VERTS) begin
									next_x[out_cnt] = buf_x[j];
									next_y[out_cnt] = buf_y[j];
									next_z[out_cnt] = buf_z[j];
									next_w[out_cnt] = buf_w[j];
									out_cnt = out_cnt + 1;
								end
                    end
                end
                // swap buffers
                for (i = 0; i < in_cnt && i < MAX_VERTS; i = i + 1) begin
                    buf_x[i] <= next_x[i];
                    buf_y[i] <= next_y[i];
                    buf_z[i] <= next_z[i];
                    buf_w[i] <= next_w[i];
                end
                in_cnt <= (out_cnt <= MAX_VERTS) ? out_cnt : MAX_VERTS;
                if (plane == BOTTOM) begin
                    state <= S_OUTPUT;
                end else begin
                    plane <= plane + 1;
                end
            end

            S_OUTPUT: begin
                vertex_count <= (in_cnt < 3) ? in_cnt[2:0] : 3;
                if (in_cnt >= 3) begin
                    out_v0_x <= buf_x[0]; out_v0_y <= buf_y[0]; out_v0_z <= buf_z[0]; out_v0_w <= buf_w[0];
                    out_v1_x <= buf_x[1]; out_v1_y <= buf_y[1]; out_v1_z <= buf_z[1]; out_v1_w <= buf_w[1];
                    out_v2_x <= buf_x[2]; out_v2_y <= buf_y[2]; out_v2_z <= buf_z[2]; out_v2_w <= buf_w[2];
                    valid_out<= 1'b1;
                end else begin
                    valid_out<= 1'b0;
                end
                state <= S_IDLE;
            end
        endcase
    end
end
endmodule
`endif
