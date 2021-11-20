`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Jilin Uni
// Engineer: Liu Yijun 2446078134@qq.com
// 
// Create Date: 2021/07/28 13:07:37
// Design Name: 
// Module Name: spi_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// SPI驱动，读写ADS1256
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_driver(
    input sys_clk,
    input rst_n,
    input spi_start_sig,
    input [23:0] spi_wr_data,
    input spi_MISO,
    output reg [23:0] spi_rd_data,
    output reg spi_MOSI,
    output spi_rd_done,
    output spi_wr_done,
    output spi_sclk
);


    reg [23:0] wr_data_buf;//读写缓冲
    reg [23:0] rd_data_buf;
    reg [4:0] clk_cnt;
    reg clk_valid;

    //读写完成信号
    assign spi_wr_done = (clk_cnt[4:0] == 5'd30) ? 1'b1 : 1'b0;
    assign spi_rd_done = (clk_cnt[4:0] == 5'd30) ? 1'b1 : 1'b0;

    assign spi_sclk = clk_valid & sys_clk;

    //读写节拍 start_sig有效时计数
    always @(posedge sys_clk) begin
        if(rst_n == 1'b0)begin
            clk_cnt[4:0] <= 5'd0;
        end
        else if(spi_start_sig == 1) begin
            clk_cnt[4:0] <= clk_cnt[4:0] + 5'd1;
        end
        else begin
            clk_cnt[4:0] <= 5'd0;
        end
    end

    //FPGA输出
    always @(posedge sys_clk) begin
        if(rst_n == 1'b0) begin
            spi_MOSI <= 1'b0;
            wr_data_buf[23:0] <= 24'd0;
        end
        else begin
            case(clk_cnt)
                5'd0 : begin
                    spi_MOSI <= 1'b0;
                    wr_data_buf[23:0] <= spi_wr_data[23:0];
                end
                5'd1 : spi_MOSI <= wr_data_buf[23];
                5'd2 : spi_MOSI <= wr_data_buf[22];
                5'd3 : spi_MOSI <= wr_data_buf[21];
                5'd4 : spi_MOSI <= wr_data_buf[20];
                5'd5 : spi_MOSI <= wr_data_buf[19];
                5'd6 : spi_MOSI <= wr_data_buf[18];
                5'd7 : spi_MOSI <= wr_data_buf[17];
                5'd8 : spi_MOSI <= wr_data_buf[16];
                5'd9 : spi_MOSI <= wr_data_buf[15];
                5'd10 : spi_MOSI <= wr_data_buf[14];
                5'd11 : spi_MOSI <= wr_data_buf[13];
                5'd12 : spi_MOSI <= wr_data_buf[12];
                5'd13 : spi_MOSI <= wr_data_buf[11];
                5'd14 : spi_MOSI <= wr_data_buf[10];
                5'd15 : spi_MOSI <= wr_data_buf[9];
                5'd16 : spi_MOSI <= wr_data_buf[8];
                5'd17 : spi_MOSI <= wr_data_buf[7];
                5'd18 : spi_MOSI <= wr_data_buf[6];
                5'd19 : spi_MOSI <= wr_data_buf[5];
                5'd20 : spi_MOSI <= wr_data_buf[4];
                5'd21 : spi_MOSI <= wr_data_buf[3];
                5'd22 : spi_MOSI <= wr_data_buf[2];
                5'd23 : spi_MOSI <= wr_data_buf[1];
                5'd24 : begin
                    spi_MOSI <= wr_data_buf[0];
                    wr_data_buf <= 0;
                end
                default : spi_MOSI <= 1'b0;
            endcase
        end
    end

    //FPGA读
    always @(negedge sys_clk) begin
        if(rst_n == 1'b0) begin
            clk_valid <= 1'b0;
            rd_data_buf[23:0] <= 24'd0;
            spi_rd_data[23:0] <= 24'd0;
        end
        else begin
            case(clk_cnt)
                5'd0 : clk_valid <= 1'b0;
                5'd1 : clk_valid <= 1'b1;
                5'd2 : rd_data_buf[23] <= spi_MISO;
                5'd3 : rd_data_buf[22] <= spi_MISO;
                5'd4 : rd_data_buf[21] <= spi_MISO;
                5'd5 : rd_data_buf[20] <= spi_MISO;
                5'd6 : rd_data_buf[19] <= spi_MISO;
                5'd7 : rd_data_buf[18] <= spi_MISO;
                5'd8 : rd_data_buf[17] <= spi_MISO;
                5'd9 : rd_data_buf[16] <= spi_MISO;
                5'd10 : rd_data_buf[15] <= spi_MISO;
                5'd11 : rd_data_buf[14] <= spi_MISO;
                5'd12 : rd_data_buf[13] <= spi_MISO;
                5'd13 : rd_data_buf[12] <= spi_MISO;
                5'd14 : rd_data_buf[11] <= spi_MISO;
                5'd15 : rd_data_buf[10] <= spi_MISO;
                5'd16 : rd_data_buf[9] <= spi_MISO;
                5'd17 : rd_data_buf[8] <= spi_MISO;
                5'd18 : rd_data_buf[7] <= spi_MISO;
                5'd19 : rd_data_buf[6] <= spi_MISO;
                5'd20 : rd_data_buf[5] <= spi_MISO;
                5'd21 : rd_data_buf[4] <= spi_MISO;
                5'd22 : rd_data_buf[3] <= spi_MISO;
                5'd23 : rd_data_buf[2] <= spi_MISO;
                5'd24 : rd_data_buf[1] <= spi_MISO;
                5'd25 : begin
                    clk_valid <= 1'b0;
                    rd_data_buf[0] <= spi_MISO;
                end
                5'd26 : spi_rd_data[23:0] <= rd_data_buf[23:0];
                default : clk_valid <= 1'b0;
            endcase
        end
    end
    

endmodule

