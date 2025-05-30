`ifndef SYNC_CONTROL_LOGIC_V
`define SYNC_CONTROL_LOGIC_V

module sync_control_logic (
    input clk, rst,                   // Đồng hồ và reset
    input start_pipeline,             // Tín hiệu khởi động pipeline
    input valid_in,                   // Tín hiệu tam giác mới từ Primitive Assembly
    input triangle_setup_valid_out,   // Tín hiệu tam giác đã xử lý từ triangle_setup
    input tile_evaluator_done,        // Tín hiệu hoàn tất tile từ tile_evaluator
    input fragment_output_buffer_ready_out, // Tín hiệu FIFO sẵn sàng từ fragment_output_buffer
    input depth_stencil_valid_out,
    output reg triangle_setup_valid_in,    // Kích hoạt triangle_setup
    output reg tile_evaluator_start,       // Kích hoạt tile_evaluator
    output reg tile_evaluator_generate_tile, // Kích hoạt tạo tile
    output reg ready_out,                  // Sẵn sàng nhận tam giác mới
    output reg pipeline_busy,              // Pipeline đang xử lý
    output reg pipeline_done,              // Pipeline hoàn tất tam giác
    output reg depth_stencil_enable
);

    // Định nghĩa các trạng thái của FSM
    reg [2:0] PState, NState;
    parameter IDLE = 3'd0,
              TRIANGLE_PROCESS = 3'd1,
              TILE_GENERATE = 3'd2,
              FRAGMENT_PROCESS = 3'd3,
              DONE = 3'd4;

    // FSM: Cập nhật trạng thái
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            PState <= IDLE;
            triangle_setup_valid_in <= 0;
            tile_evaluator_start <= 0;
            tile_evaluator_generate_tile <= 0;
            ready_out <= 0;
            pipeline_busy <= 0;
            pipeline_done <= 0;
            depth_stencil_enable <= 0;
        end
        else begin
            PState <= NState;
                triangle_setup_valid_in <= 0;
                tile_evaluator_start <= 0;
                tile_evaluator_generate_tile <= 0;
                ready_out <= 0;
                pipeline_busy <= 0;
                pipeline_done <= 0;
                depth_stencil_enable <= 0;
            // Cập nhật tín hiệu điều khiển
            case (NState)
                IDLE: begin
                    ready_out <= 1;
                end
                TRIANGLE_PROCESS: begin
                    triangle_setup_valid_in <= 1;
                    pipeline_busy <= 1;
                end
                TILE_GENERATE: begin
                    tile_evaluator_start <= 1;
                    tile_evaluator_generate_tile <= 1;
                    pipeline_busy <= 1;
                end
                FRAGMENT_PROCESS: begin
                    pipeline_busy <= 1;
                    depth_stencil_enable <= 1;
                end
                DONE: begin
                    ready_out <= 1;
                    pipeline_done <= 1;
                end
            endcase
        end
    end

    // FSM: Logic chuyển trạng thái
    always @(*) begin
        NState = PState;
        case (PState)
            IDLE: begin
                if (start_pipeline && valid_in && fragment_output_buffer_ready_out) begin
                    NState = TRIANGLE_PROCESS;
                end
            end
            TRIANGLE_PROCESS: begin
                if (triangle_setup_valid_out) begin
                    NState = TILE_GENERATE;
                end
            end
            TILE_GENERATE: begin
                if (tile_evaluator_done) begin
                    NState = FRAGMENT_PROCESS;
                end
            end
            FRAGMENT_PROCESS: begin
                // Giả định fragment xử lý hoàn tất khi FIFO sẵn sàng và không còn tile mới
                if (fragment_output_buffer_ready_out) begin
                    NState = DONE;
                end
            end
            DONE: begin
                if (valid_in && fragment_output_buffer_ready_out) begin
                    NState = TRIANGLE_PROCESS;
                end
                else begin
                    NState = IDLE;
                end
            end
            default: begin
                NState = IDLE;
            end
        endcase
    end

endmodule

`endif