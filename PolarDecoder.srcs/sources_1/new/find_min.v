`timescale 1ns / 1ns

module find_min_2
    #(parameter DATA_WIDTH=8, parameter LABEL_WIDTH=3)
    (
        input wire clk,
        input wire [DATA_WIDTH-1:0] data_A,
        input wire [LABEL_WIDTH-1:0] label_A,

        input wire [DATA_WIDTH-1:0] data_B,
        input wire [LABEL_WIDTH-1:0] label_B,

        input wire input_ready,

        output reg [DATA_WIDTH-1:0] data_out,
        output reg [LABEL_WIDTH-1:0] label_out,
        output reg output_ready
    );

    always@(posedge clk) begin
        if(data_A < data_B) begin
            data_out <= data_A;
            label_out <= label_A;
        end else begin
            data_out <= data_B;
            label_out <= label_B;
        end

        output_ready <= input_ready;
    end

endmodule

module find_min
    #(parameter DATA_WIDTH=8, parameter LABEL_WIDTH=3, parameter LOG_INPUT_NUM=3)
    (
        input wire clk,
        input wire [(2**LOG_INPUT_NUM)*DATA_WIDTH-1:0] input_data,
        input wire [(2**LOG_INPUT_NUM)*LABEL_WIDTH-1:0] input_labels,
        input wire input_ready,

        output wire [DATA_WIDTH-1:0] output_data,
        output wire [LABEL_WIDTH-1:0] output_label,
        output wire output_ready
    );

    genvar i;
    genvar j;

    // using recursive verilog programming.
    if(LOG_INPUT_NUM == 1) begin
        find_min_2 #(.DATA_WIDTH(DATA_WIDTH), .LABEL_WIDTH(LABEL_WIDTH)) fm2(.clk(clk), .data_A(input_data[DATA_WIDTH-1:0]), .label_A(input_labels[LABEL_WIDTH-1:0]),
                                                                            .data_B(input_data[2*DATA_WIDTH-1:DATA_WIDTH]), .label_B(input_labels[2*LABEL_WIDTH-1:LABEL_WIDTH]), .input_ready(input_ready),
                                                                            .data_out(output_data), .label_out(output_label), .output_ready(output_ready));
    end else begin
        // Divide the input array into two parts.
        localparam lm1 = LOG_INPUT_NUM - 1;
        wire [(2**lm1)*DATA_WIDTH-1:0] input_data_0;
        wire [(2**lm1)*DATA_WIDTH-1:0] input_data_1;
        wire [(2**lm1)*LABEL_WIDTH-1:0] input_label_0;
        wire [(2**lm1)*LABEL_WIDTH-1:0] input_label_1;

        assign input_data_0 = input_data[(2**lm1)*DATA_WIDTH-1:0];
        assign input_data_1 = input_data[(2**LOG_INPUT_NUM)*DATA_WIDTH-1:(2**lm1)*DATA_WIDTH];
        assign input_label_0 = input_labels[(2**lm1)*LABEL_WIDTH-1:0];
        assign input_label_1 = input_labels[(2**LOG_INPUT_NUM)*LABEL_WIDTH-1:(2**lm1)*LABEL_WIDTH];

        wire [DATA_WIDTH-1:0] output_data_0;
        wire [LABEL_WIDTH-1:0] output_label_0;
        wire [DATA_WIDTH-1:0] output_data_1;
        wire [LABEL_WIDTH-1:0] output_label_1;

        wire output_ready_0, output_ready_1;

        find_min #(.DATA_WIDTH(DATA_WIDTH), .LABEL_WIDTH(LABEL_WIDTH), .LOG_INPUT_NUM(lm1)) fmn_0(.clk(clk), .input_data(input_data_0), .input_labels(input_label_0),
                                                                                                .input_ready(input_ready), 
                                                                                                .output_data(output_data_0), .output_label(output_label_0), .output_ready(output_ready_0));
        find_min #(.DATA_WIDTH(DATA_WIDTH), .LABEL_WIDTH(LABEL_WIDTH), .LOG_INPUT_NUM(lm1)) fmn_1(.clk(clk), .input_data(input_data_1), .input_labels(input_label_1),
                                                                                                .input_ready(input_ready), 
                                                                                                .output_data(output_data_1), .output_label(output_label_1), .output_ready(output_ready_1));     

        find_min_2 #(.DATA_WIDTH(DATA_WIDTH), .LABEL_WIDTH(LABEL_WIDTH)) fm2(.clk(clk), .data_A(output_data_0), .label_A(output_label_0),
                                                                            .data_B(output_data_1), .label_B(output_label_1), .input_ready(output_ready_0),
                                                                            .data_out(output_data), .label_out(output_label), .output_ready(output_ready));                                                                       

    end



endmodule