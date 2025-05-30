`ifndef RASTERIZATION_V
`define RASTERIZATION_V
`include "primitive_assembly.v"
`include "clipping_unit.v"
`include "perspective_division.v"
`include "triangle_setup.v"
`include "fragment_generator.v"
`include "interpolator.v"
module rasterization #(
    parameter COORD_W = 32,
    parameter COEFF_W = 16,
    parameter T = 16,
    parameter DEPTH_W = 32,
    parameter COLOR_W = 24,
    parameter SCREEN_W = 1024,
    parameter SCREEN_H = 1024,
    parameter MAX_VERTS = 12,
    parameter FIFO_DEPTH = 16
)(
    input clk, rst,
    input valid_in,
    input [COORD_W - 1 : 0] vertex_x, vertex_y, vertex_z, vertex_w,
    output valid_out,
    output [COORD_W - 1 : 0] frag_x_out, frag_y_out,
    output [COLOR_W - 1 : 0] color_r_out, color_g_out, color_b_out,
    output [DEPTH_W - 1 : 0] depth_out
);
    // Dây nối giữa các module
    wire pa_valid_out;
    wire [COORD_W-1:0] pa_x0, pa_y0, pa_z0, pa_w0;
    wire [COORD_W-1:0] pa_x1, pa_y1, pa_z1, pa_w1;
    wire [COORD_W-1:0] pa_x2, pa_y2, pa_z2, pa_w2;

    wire clip_valid_out;
    wire [COORD_W-1:0] clip_out_v0_x, clip_out_v0_y, clip_out_v0_z, clip_out_v0_w;
    wire [COORD_W-1:0] clip_out_v1_x, clip_out_v1_y, clip_out_v1_z, clip_out_v1_w;
    wire [COORD_W-1:0] clip_out_v2_x, clip_out_v2_y, clip_out_v2_z, clip_out_v2_w;

    wire pd_valid_out;
    wire [COORD_W-1:0] pd_out_v0_x, pd_out_v0_y, pd_out_v0_z;
    wire [COORD_W-1:0] pd_out_v1_x, pd_out_v1_y, pd_out_v1_z;
    wire [COORD_W-1:0] pd_out_v2_x, pd_out_v2_y, pd_out_v2_z;

    wire ts_valid_out;
    wire [COEFF_W-1:0] ts_a0, ts_a1, ts_a2, ts_b0, ts_b1, ts_b2, ts_c0, ts_c1, ts_c2;
    wire [COORD_W-1:0] ts_min_x, ts_min_y, ts_max_x, ts_max_y;
    wire [2*DEPTH_W-1:0] ts_denom;

    wire fg_valid_out_ds;
    wire [COORD_W-1:0] fg_fragment_x_out_ds, fg_fragment_y_out_ds;
    wire [DEPTH_W-1:0] fg_fragment_z_out_ds;

    wire interp_valid_out;
    wire [COORD_W-1:0] interp_frag_x_out, interp_frag_y_out;
    wire [COLOR_W-1:0] interp_color_r_out, interp_color_g_out, interp_color_b_out;
    wire [DEPTH_W-1:0] interp_depth_out;
    

    primitive_assembly pa (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .vertex_x(vertex_x),
        .vertex_y(vertex_y),
        .vertex_z(vertex_z),
        .vertex_w(vertex_w),
        .ready_out(),
        .valid_out(pa_valid_out),
        .x0(pa_x0), .y0(pa_y0), .z0(pa_z0), .w0(pa_w0),
        .x1(pa_x1), .y1(pa_y1), .z1(pa_z1), .w1(pa_w1),
        .x2(pa_x2), .y2(pa_y2), .z2(pa_z2), .w2(pa_w2)
    );
    // Clipping Unit
    clipping_unit #(
        .COORD_W(COORD_W),
        .MAX_VERTS(MAX_VERTS)
    ) u_clipping_unit (
        .clk(clk),
        .rst(rst),
        .valid_in(pa_valid_out),
        .v0_x(pa_x0), .v0_y(pa_y0), .v0_z(pa_z0), .v0_w(pa_w0),
        .v1_x(pa_x1), .v1_y(pa_y1), .v1_z(pa_z1), .v1_w(pa_w1),
        .v2_x(pa_x2), .v2_y(pa_y2), .v2_z(pa_z2), .v2_w(pa_w2),
        .valid_out(clip_valid_out),
        .out_v0_x(clip_out_v0_x), .out_v0_y(clip_out_v0_y), .out_v0_z(clip_out_v0_z), .out_v0_w(clip_out_v0_w),
        .out_v1_x(clip_out_v1_x), .out_v1_y(clip_out_v1_y), .out_v1_z(clip_out_v1_z), .out_v1_w(clip_out_v1_w),
        .out_v2_x(clip_out_v2_x), .out_v2_y(clip_out_v2_y), .out_v2_z(clip_out_v2_z), .out_v2_w(clip_out_v2_w),
        .vertex_count()
    );

    // Perspective Division
    perspective_division #(
        .COORD_W(COORD_W),
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H)
    ) u_perspective_division (
        .clk(clk),
        .rst(rst),
        .valid_in(clip_valid_out),
        .v0_x(clip_out_v0_x), .v0_y(clip_out_v0_y), .v0_z(clip_out_v0_z), .v0_w(clip_out_v0_w),
        .v1_x(clip_out_v1_x), .v1_y(clip_out_v1_y), .v1_z(clip_out_v1_z), .v1_w(clip_out_v1_w),
        .v2_x(clip_out_v2_x), .v2_y(clip_out_v2_y), .v2_z(clip_out_v2_z), .v2_w(clip_out_v2_w),
        .valid_out(pd_valid_out),
        .out_v0_x(pd_out_v0_x), .out_v0_y(pd_out_v0_y), .out_v0_z(pd_out_v0_z),
        .out_v1_x(pd_out_v1_x), .out_v1_y(pd_out_v1_y), .out_v1_z(pd_out_v1_z),
        .out_v2_x(pd_out_v2_x), .out_v2_y(pd_out_v2_y), .out_v2_z(pd_out_v2_z)
    );

    // Triangle Setup
    triangle_setup #(
        .COORD_W(COORD_W),
        .COEFF_W(COEFF_W),
        .DEPTH_W(DEPTH_W)
    ) u_triangle_setup (
        .clk(clk),
        .rst(rst),
        .valid_in(pd_valid_out),
        .x0(pd_out_v0_x), .y0(pd_out_v0_y), .z0(pd_out_v0_z),
        .x1(pd_out_v1_x), .y1(pd_out_v1_y), .z1(pd_out_v1_z),
        .x2(pd_out_v2_x), .y2(pd_out_v2_y), .z2(pd_out_v2_z),
        .valid_out(ts_valid_out),
        .a0(ts_a0), .a1(ts_a1), .a2(ts_a2),
        .b0(ts_b0), .b1(ts_b1), .b2(ts_b2),
        .c0(ts_c0), .c1(ts_c1), .c2(ts_c2),
        .min_x(ts_min_x), .min_y(ts_min_y),
        .max_x(ts_max_x), .max_y(ts_max_y),
        .denom(ts_denom)
    );

    // Fragment Generator
    fragment_generator #(
        .COORD_W(COORD_W),
        .INPUT_COORD_W(COORD_W),
        .COEFF_W(COEFF_W),
        .DEPTH_W(DEPTH_W),
        .T(T),
        .FIFO_DEPTH(FIFO_DEPTH),
        .SCREEN_H(SCREEN_H),
        .SCREEN_W(SCREEN_W)
    ) u_fragment_generator (
        .clk(clk),
        .rst(rst),
        .start_pipeline(1'b1), // Giả định luôn bắt đầu pipeline
        .valid_in(ts_valid_out),
        .x0_in(pd_out_v0_x), .y0_in(pd_out_v0_y), .z0_in(pd_out_v0_z),
        .x1_in(pd_out_v1_x), .y1_in(pd_out_v1_y), .z1_in(pd_out_v1_z),
        .x2_in(pd_out_v2_x), .y2_in(pd_out_v2_y), .z2_in(pd_out_v2_z),
        .a0(ts_a0), .a1(ts_a1), .a2(ts_a2),
        .b0(ts_b0), .b1(ts_b1), .b2(ts_b2),
        .c0(ts_c0), .c1(ts_c1), .c2(ts_c2),
        .min_x_in(ts_min_x), .min_y_in(ts_min_y), .max_x_in(ts_max_x), .max_y_in(ts_max_y),
        .denom(ts_denom),
        .depth_stencil_enable(1'b1), // Giả định bật depth/stencil
        .valid_out_ds(fg_valid_out_ds),
        .fragment_x_out_ds(fg_fragment_x_out_ds),
        .fragment_y_out_ds(fg_fragment_y_out_ds),
        .fragment_z_out_ds(fg_fragment_z_out_ds),
        .depth_write(),
        .stencil_write(),
        .pipeline_busy(),
        .pipeline_done()
    );

    // Interpolator
    interpolator #(
        .COORD_W(COORD_W),
        .COEFF_W(COEFF_W),
        .DEPTH_W(DEPTH_W)
    ) u_interpolator (
        .clk(clk),
        .rst(rst),
        .valid_in(fg_valid_out_ds),
        .ready_out(),
        .frag_x(fg_fragment_x_out_ds),
        .frag_y(fg_fragment_y_out_ds),
        .u0(), .u1(), .u2(), // Cần thêm logic để tính barycentric coordinates
        .inv_sum(),         // Cần thêm logic để tính inv_sum
        .v0_r(24'hFF0000), .v1_r(24'h00FF00), .v2_r(24'h0000FF), // Màu giả định
        .v0_g(24'h00FF00), .v1_g(24'h0000FF), .v2_g(24'hFF0000),
        .v0_b(24'h0000FF), .v1_b(24'hFF0000), .v2_b(24'h00FF00),
        .v0_z(pd_out_v0_z), .v1_z(pd_out_v1_z), .v2_z(pd_out_v2_z),
        .valid_out(interp_valid_out),
        .frag_x_out(interp_frag_x_out),
        .frag_y_out(interp_frag_y_out),
        .color_r_out(interp_color_r_out),
        .color_g_out(interp_color_g_out),
        .color_b_out(interp_color_b_out),
        .depth_out(interp_depth_out)
    );

    // Gán đầu ra
    assign valid_out = interp_valid_out;
    assign frag_x_out = interp_frag_x_out;
    assign frag_y_out = interp_frag_y_out;
    assign color_r_out = interp_color_r_out;
    assign color_g_out = interp_color_g_out;
    assign color_b_out = interp_color_b_out;
    assign depth_out = interp_depth_out;
endmodule   
`endif