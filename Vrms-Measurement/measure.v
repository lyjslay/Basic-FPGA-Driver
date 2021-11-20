`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/09/17 20:04:05
// Design Name: 
// Module Name: measure
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module measure(
    input clk_sys,
    input clk_samp,//1M分频时钟
    input rst_n,
    input mearsure_start,
    input [11:0] AD_data,
    output measure_done_q,
    output [21:0] data_out
);
    parameter cnt_clear = 22'd255;//采样255个平方值
    reg clk_samp_buf0;
    reg clk_samp_buf1;
    wire clk_samp_impluse;
    wire [21:0] mult_data;
    reg [16:0] cnt;
    reg [39:0] sig_energy;
    reg [21:0] data_out_buf;
    reg measure_en;
    wire measure_done;

    assign measure_done = (cnt == cnt_clear) ? 1'b1:1'b0;
    assign measure_done_q = measure_done;
    assign data_out  = data_out_buf;
    assign clk_samp_impluse = clk_samp_buf0 & ~clk_samp_buf1;//通过两个相差一个时钟周期的信号产生一个系统时钟周期的采样脉冲

    //生成采样脉冲
    always@(posedge clk_sys) begin
        clk_samp_buf0 <= clk_samp;
        clk_samp_buf1 <= clk_samp_buf0;//clk_samp_buf1相对于clk_samp延迟了一个系统时钟周期
    end

    //产生测量使能信号
    always@(posedge clk_sys) begin
        if(!rst_n) begin
            measure_en <= 1'b0;
        end
        else if(mearsure_start)
            measure_en <= 1'b1;
        else if(measure_done)
            measure_en <= 1'b0;
        else
            measure_en <= measure_en;
    end

    //对信号的平方值进行累加，即+mult_data
    always@(posedge clk_sys) begin
        if(!rst_n) begin
            sig_energy <= 40'd0;
            cnt <= 17'd0;
            data_out_buf <= 22'd0;
        end
        else if(cnt == cnt_clear) begin
            sig_energy <= 40'd0;
            data_out_buf <= sig_energy[39:8];
            cnt <= 17'd0;
        end
        else if(clk_samp_impluse && measure_en) begin
            cnt <= cnt + 17'd1;
            sig_energy <= sig_energy + mult_data;
        end
        else begin
            sig_energy <= sig_energy;
            data_out_buf <= data_out_buf;
            cnt <= cnt;
        end
    end

   mult1 mult1_inst(
    .A(AD_data),
    .B(AD_data),
    .P(mult_data),
    .CLK(clk_sys),
    .CE(clk_samp_impluse)
    );

endmodule
