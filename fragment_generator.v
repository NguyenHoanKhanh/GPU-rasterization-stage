`ifndef FRAGMENT_GENERATOR_V
`define FRAGMENT_GENERATOR_V
`timescale 1ns/1ps
`include "coord_converter.v"
`include "tile_evaluator.v"
`include "edge_function_evaluator.v"
`include "tile_traverser.v"
`include "fragment_emitter.v"
`include "depth_interpolator.v"
`include "attribute_interpolator.v"
`include "fragment_output_buffer.v"
`include "hierarchical_z.v"
`include "depth_stencil_test.v"
`include "sync_control_logic.v"

module fragment_generator #(
    parameter COORD_W = 10,
    parameter INPUT_COORD_W = 32,
    parameter COEFF_W = 16,
    parameter DEPTH_W = 32,
    parameter T = 16,
    parameter FIFO_DEPTH = 16,
    parameter SCREEN_H = 16,
    parameter SCREEN_W = 16
) (
    input clk, rst,
    input start_pipeline,
    input valid_in,
    input [INPUT_COORD_W - 1 : 0] x0_in, y0_in, z0_in,
    input [INPUT_COORD_W - 1 : 0] x1_in, y1_in, z1_in,
    input [INPUT_COORD_W - 1 : 0] x2_in, y2_in, z2_in,
    input [COEFF_W - 1 : 0] a0, a1, a2, b0, b1, b2, c0, c1, c2,
    input [INPUT_COORD_W - 1 : 0] min_x_in, min_y_in, max_x_in, max_y_in,
    input [2 * DEPTH_W - 1 : 0] denom,
    input depth_stencil_enable,
    output valid_out_ds,
    output [COORD_W-1:0] fragment_x_out_ds,
    output [COORD_W-1:0] fragment_y_out_ds,
    output [DEPTH_W-1:0] fragment_z_out_ds,
    output depth_write,
    output stencil_write,
    output pipeline_busy,
    output pipeline_done
);

    wire [COORD_W-1:0] min_x, min_y, max_x, max_y;
    wire [COORD_W-1:0] x0, y0, x1, y1, x2, y2;
    wire [COORD_W-1:0] tile_x, tile_y;
    wire tile_inside;
    wire [31:0] e0, e1, e2;
    wire [COORD_W-1:0] tile_x_out, tile_y_out;
    wire [COORD_W-1:0] frag_x, frag_y;
    wire [DEPTH_W-1:0] frag_z;
    wire triangle_setup_valid_out;
    wire tile_evaluator_valid, tile_evaluator_done;
    wire edge_valid_out;
    wire traverser_valid_out, traverser_done_out;
    wire emitter_valid_out, emitter_done_out;
    wire depth_valid_out;
    wire attr_valid_out;
    wire tile_evaluator_start, tile_evaluator_generate_tile;
    wire ready_out, ready_in;
    wire [COORD_W-1:0] fragment_x_out_buffer, fragment_y_out_buffer;
    wire [DEPTH_W-1:0] fragment_z_out_buffer;
    wire valid_out_buffer;
    wire fragment_buffer_ready;
    wire [COORD_W-1:0] fragment_x_out_hiz, fragment_y_out_hiz;
    wire [DEPTH_W-1:0] fragment_z_out_hiz;
    wire valid_out_hiz;

    // Module coord_converter
    coord_converter #(
        .INPUT_W(INPUT_COORD_W),
        .OUTPUT_W(COORD_W)
    ) u_coord_converter (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .in_min_x(min_x_in),
        .in_min_y(min_y_in),
        .in_max_x(max_x_in),
        .in_max_y(max_y_in),
        .in_x0(x0_in),
        .in_y0(y0_in),
        .in_x1(x1_in),
        .in_y1(y1_in),
        .in_x2(x2_in),
        .in_y2(y2_in),
        .out_min_x(min_x),
        .out_min_y(min_y),
        .out_max_x(max_x),
        .out_max_y(max_y),
        .out_x0(x0),
        .out_y0(y0),
        .out_x1(x1),
        .out_y1(y1),
        .out_x2(x2),
        .out_y2(y2)
    );

    // Module tile_evaluator
    tile_evaluator #(
        .T(T),
        .COORD_W(COORD_W)
    ) u_tile_evaluator (
        .clk(clk),
        .rst(rst),
        .start(tile_evaluator_start),
        .generate_tile(tile_evaluator_generate_tile),
        .min_x(min_x),
        .min_y(min_y),
        .max_x(max_x),
        .max_y(max_y),
        .valid(tile_evaluator_valid),
        .tile_x(tile_x),
        .tile_y(tile_y),
        .done(tile_evaluator_done)
    );

    // Module edge_function_evaluator
    edge_function_evaluator #(
        .COORD_W(COORD_W),
        .COEFF_W(COEFF_W),
        .T(T)
    ) u_edge_function_evaluator (
        .clk(clk),
        .rst(rst),
        .valid_in(tile_evaluator_valid),
        .a0(a0), .b0(b0), .c0(c0),
        .a1(a1), .b1(b1), .c1(c1),
        .a2(a2), .b2(b2), .c2(c2),
        .tile_x(tile_x),
        .tile_y(tile_y),
        .valid_out(edge_valid_out),
        .tile_inside(tile_inside),
        .e0(e0), .e1(e1), .e2(e2)
    );

    // Module tile_traverser
    tile_traverser #(
        .COORD_W(COORD_W)
    ) u_tile_traverser (
        .clk(clk),
        .rst(rst),
        .valid_in(edge_valid_out),
        .tile_x(tile_x),
        .tile_y(tile_y),
        .tile_inside(tile_inside),
        .done_in(tile_evaluator_done),
        .min_x(min_x),
        .min_y(min_y),
        .max_x(max_x),
        .max_y(max_y),
        .valid_out(traverser_valid_out),
        .tile_x_out(tile_x_out),
        .tile_y_out(tile_y_out),
        .done_out(traverser_done_out)
    );

    // Module fragment_emitter
    fragment_emitter #(
        .COORD_W(COORD_W),
        .COEFF_W(COEFF_W),
        .T(T)
    ) u_fragment_emitter (
        .clk(clk),
        .rst(rst),
        .valid_in(traverser_valid_out),
        .tile_x(tile_x_out),
        .tile_y(tile_y_out),
        .tile_inside(tile_inside),
        .e0(e0), .e1(e1), .e2(e2),
        .a0(a0), .a1(a1), .a2(a2),
        .valid_out(emitter_valid_out),
        .frag_x(frag_x),
        .frag_y(frag_y),
        .done_out(emitter_done_out)
    );

    // Module depth_interpolator
    wire [COORD_W-1:0] depth_frag_x, depth_frag_y;
    depth_interpolator #(
        .COORD_W(COORD_W),
        .DEPTH_W(DEPTH_W)
    ) u_depth_interpolator (
        .clk(clk),
        .rst(rst),
        .valid_in(emitter_valid_out),
        .frag_x(frag_x),
        .frag_y(frag_y),
        .x0(x0), .y0(y0), .x1(x1), .y1(y1), .x2(x2), .y2(y2),
        .z0(z0_in), .z1(z1_in), .z2(z2_in),
        .denom(denom),
        .valid_out(depth_valid_out),
        .out_frag_x(depth_frag_x),
        .out_frag_y(depth_frag_y),
        .frag_z(frag_z)
    );

    // Module attribute_interpolator
    wire [COORD_W-1:0] attr_frag_x, attr_frag_y;
    wire [DEPTH_W-1:0] attr_frag_z;
    attribute_interpolator #(
        .COORD_W(COORD_W),
        .DEPTH_W(DEPTH_W)
    ) u_attribute_interpolator (
        .clk(clk),
        .rst(rst),
        .valid_in(depth_valid_out),
        .frag_x(depth_frag_x),
        .frag_y(depth_frag_y),
        .frag_z(frag_z),
        .valid_out(attr_valid_out),
        .out_frag_x(attr_frag_x),
        .out_frag_y(attr_frag_y),
        .out_frag_z(attr_frag_z)
    );

    // Module fragment_output_buffer
    fragment_output_buffer #(
        .COORD_W(COORD_W),
        .DEPTH_W(DEPTH_W),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fragment_output_buffer (
        .clk(clk),
        .rst(rst),
        .valid_in(attr_valid_out),
        .fragment_x_in(attr_frag_x),
        .fragment_y_in(attr_frag_y),
        .fragment_z_in(attr_frag_z),
        .ready_in(ready_in),
        .ready_out(fragment_buffer_ready),
        .valid_out_buffer(valid_out_buffer),
        .fragment_x_out(fragment_x_out_buffer),
        .fragment_y_out(fragment_y_out_buffer),
        .fragment_z_out(fragment_z_out_buffer)
    );

    // Module hierarchical_z
    hierarchical_z #(
        .COORD_W(COORD_W),
        .DEPTH_W(DEPTH_W),
        .SCREEN_H(SCREEN_H),
        .SCREEN_W(SCREEN_W)
    ) hiz (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_out_buffer),
        .hiz_enable(depth_stencil_enable),
        .frag_x(fragment_x_out_buffer),
        .frag_y(fragment_y_out_buffer),
        .frag_z(fragment_z_out_buffer),
        .valid_out(valid_out_hiz),
        .frag_x_out(fragment_x_out_hiz),
        .frag_y_out(fragment_y_out_hiz),
        .frag_z_out(fragment_z_out_hiz),
        .depth_write(),
        .hiz_update()
    );

    // Module depth_stencil_test
    depth_stencil_test #(
        .COORD_W(COORD_W),
        .DEPTH_W(DEPTH_W),
        .STENCIL_W(8),
        .SCREEN_W(16),
        .SCREEN_H(16)
    ) u_depth_stencil_test (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_out_hiz),
        .depth_enable(depth_stencil_enable),
        .stencil_enable(depth_stencil_enable),
        .frag_x(fragment_x_out_hiz),
        .frag_y(fragment_x_out_hiz),
        .frag_z(fragment_z_out_hiz),
        .stencil_ref(8'h01),
        .stencil_mask(8'hFF),
        .stencil_func(3'd2), // GL_EQUAL
        .stencil_sfail(3'd0), // GL_KEEP
        .stencil_dpfail(3'd0), // GL_KEEP
        .stencil_dppass(3'd2), // GL_REPLACE
        .depth_func(3'd1), // GL_LESS
        .valid_out(valid_out_ds),
        .frag_x_out(fragment_x_out_ds),
        .frag_y_out(fragment_y_out_ds),
        .frag_z_out(fragment_z_out_ds),
        .depth_write(depth_write),
        .stencil_write(stencil_write)
    );

    // Module sync_control_logic
    sync_control_logic u_sync_control_logic (
        .clk(clk),
        .rst(rst),
        .start_pipeline(start_pipeline),
        .valid_in(valid_in),
        .triangle_setup_valid_out(valid_in),
        .tile_evaluator_done(tile_evaluator_done),
        .fragment_output_buffer_ready_out(fragment_buffer_ready),
        .triangle_setup_valid_in(),
        .tile_evaluator_start(tile_evaluator_start),
        .tile_evaluator_generate_tile(tile_evaluator_generate_tile),
        .ready_out(ready_out),
        .pipeline_busy(pipeline_busy),
        .pipeline_done(pipeline_done)
    );

    assign ready_in = 1'b1;

endmodule

`endif
