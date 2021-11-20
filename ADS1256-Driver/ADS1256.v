`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: JLU
// Engineer: Liu Yijun 2446078134@qq.com
// 
// Create Date: 2021/07/28 16:16:07
// Design Name: 
// Module Name: ADS1256
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


module ADS1256(
    input sys_clk,
    input rst_n,
    //input enable,
    input AD_out,
    input DRDY_n,	//由于setting time的影响,AD拉低DRDY_n信号时才能开始读书记
                                                    
    output sclk,
    output write_AD_data,
    output reg AD_cs_n,
    output AD_rst_n,                                          
    output reg [23:0] AD_value,
    output reg oAd_conv_done
);

    //根据数据手册写寄存器设置模式
    parameter STATUS_REG = 8'b0000_0001; // 状态寄存器
    parameter MUX_REG = 8'b0001_1111; // 通道寄存器 正通道AIN1,负通道AINCOM
    parameter ADCON_REG = 8'b0010_0000; // 控制寄存器 CLOCK OUT Frequency=Fclkin=7.68M,传感器检测关闭,可编程增益放大器为1
    parameter DRATE_REG = 8'b1111_0000; // 数据速率寄存器 30000SPS(默认)
    parameter IO_REG = 8'b1110_0000; // IO寄存器 D3D2D1输入,D0输出
    //寄存器地址
    parameter STATUS_REG_ADDR = 4'h0;
    parameter MUX_REG_ADDR = 4'h1;
    parameter ADCON_REG_ADDR = 4'h2;
    parameter DRATE_REG_ADDR = 4'h3;
    parameter IO_REG_ADDR = 4'h4;
    //AD指令码
    parameter WAKEUP = 8'h00;
    parameter RDATA = 8'h01;
    parameter RDATAC = 8'h03;
    parameter SDATAC = 8'h0f;
    parameter SELFCAL = 8'hf0;
    parameter SELFOCAL = 8'hf1;
    parameter SELFGCAL = 8'hf2;
    parameter SYSOCAL = 8'hf3;
    parameter SYSGCAL = 8'hf4;
    parameter SYNC = 8'hfc;
    parameter STANDBY = 8'hfd;
    parameter RESET = 8'hfe;

    //状态机定义
    parameter ST_IDLE = 10'b00_0000_0001;
    parameter ST_TX_STATUS = 10'b00_0000_0010;//写状态
    parameter ST_TX_ADCON = 10'b00_0000_0100;//写AD控制寄存器
    parameter ST_TX_DRATE = 10'b00_0000_1000;//写数据速率寄存器
    parameter ST_TX_IO = 10'b00_0001_0000;//写IO寄存器
    parameter ST_TX_MUX = 10'b00_0010_0000;
    parameter ST_TX_RDATA = 10'b00_0100_0000;
    parameter ST_WAITING = 10'b00_1000_0000;
    parameter ST_READ_DATA = 10'b01_0000_0000;
    parameter ST_CONV_END = 10'b10_0000_0000;


    wire spi_rd_done;//读完成标志
    wire spi_wr_done;
    wire [23:0] spi_rd_data;
    reg [4:0] delay_cnt;
    reg [23:0] spi_wr_data;
    reg spi_start_sig;
    reg enable = 1;

    assign AD_rst_n = 1'b1; //不负位


    reg [9:0] state;
    reg [9:0] next_state;
    wire clk_fsm;

    always @(posedge clk_fsm) begin
        if(!rst_n) begin
            state <= ST_IDLE;
        end
        else begin 
            state <= next_state;
        end
    end

    always @(*) begin
        if(!rst_n) begin 
            next_state = ST_IDLE;
        end
        else begin
            case (state)
                ST_IDLE : next_state = (enable == 1'b1) ? ST_TX_STATUS : ST_IDLE;
                ST_TX_STATUS : next_state = (spi_wr_done == 1'b1) ? ST_TX_ADCON : ST_TX_STATUS;
                ST_TX_ADCON : next_state = (spi_wr_done == 1'b1) ? ST_TX_DRATE : ST_TX_ADCON;
                ST_TX_DRATE : next_state = (spi_wr_done == 1'b1) ? ST_TX_IO : ST_TX_DRATE;
                ST_TX_IO : next_state = (spi_wr_done == 1'b1) ? ST_TX_MUX : ST_TX_IO;
                ST_TX_MUX : next_state = (spi_wr_done == 1'b1) ? ST_TX_RDATA : ST_TX_MUX;
                ST_TX_RDATA : next_state = (spi_wr_done == 1'b1) ? ST_WAITING : ST_TX_RDATA;//这里不等DRDY为低就跳转状态是为了防止卡死
                ST_WAITING : next_state = (delay_cnt == 5'd6) ? ST_READ_DATA : ST_WAITING;
                ST_READ_DATA : next_state = (spi_rd_done == 1'b1) ? ST_CONV_END : ST_READ_DATA;
                ST_CONV_END : next_state = ST_IDLE;
                default : next_state = ST_IDLE;
            endcase
        end
    end


    always @ (posedge clk_fsm) begin
        if(!rst_n)begin
            AD_cs_n <= 1'b1;
            oAd_conv_done <= 1'b0;
            spi_start_sig <= 1'b0;
            delay_cnt <= 5'd0;
            spi_wr_data <= 24'd0;
            AD_value <= 24'd0;
        end
        else begin
            case(state)
                ST_IDLE : begin
                    AD_cs_n <= 1'b1;
                    //oAd_conv_done <= 1'b0;
                    spi_start_sig <= 1'b0;
                    delay_cnt <= 5'd0;
                    spi_wr_data <= 24'd0;
                end
                ST_TX_STATUS : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b1;
                    spi_wr_data <= {4'h5,STATUS_REG_ADDR,8'h00,STATUS_REG}; // 写状态寄存器
                end
                ST_TX_ADCON : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b1;
                    spi_wr_data <= {4'h5,ADCON_REG_ADDR,8'h00,ADCON_REG}; // 写A/D控制寄存器
                end
                ST_TX_DRATE : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b1;
                    spi_wr_data <= {4'h5,DRATE_REG_ADDR,8'h00,DRATE_REG}; // 写数据速率寄存器
                end
                ST_TX_IO : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b1;
                    spi_wr_data <= {4'h5,IO_REG_ADDR,8'h00,IO_REG}; // 写IO寄存器
                end
                ST_TX_MUX : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b1;
                    spi_wr_data <= {4'h5,MUX_REG_ADDR,8'h00,MUX_REG}; // 写输入通道寄存器
                end
                ST_TX_RDATA : begin
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= (spi_wr_done != 1'b1) ? 1'b1 : 1'b0;
                    if(DRDY_n == 1'b0) begin
                        spi_wr_data <= {SYNC,WAKEUP,RDATA}; // 发送同步、唤醒、读数据命令
                    end
                end
                ST_WAITING : begin // 等待
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= 1'b0;
                    spi_wr_data <= 24'd0;
                    delay_cnt <= (delay_cnt == 5'd6) ? 5'd0 : (delay_cnt + 5'd1);
                end
                ST_READ_DATA : begin // 读数据
                    AD_cs_n <= 1'b0;
                    spi_start_sig <= (spi_rd_done != 1'b1) ? 1'b1 : 1'b0;
                    AD_value <= (spi_rd_done == 1'b1) ? spi_rd_data : AD_value;
                end
                ST_CONV_END : begin
                    AD_cs_n <= 1'b0;
                    oAd_conv_done <= 1'b1;
                    spi_start_sig <= 1'b0;
                    spi_wr_data <= 24'd0;
                end
                default : ;
            endcase
        end
    end

spi_driver spidrv(
    //in
    .sys_clk(sys_clk),
    .rst_n(rst_n),
    .spi_start_sig(spi_start_sig),
    .spi_wr_data(spi_wr_data),
    .spi_MISO(AD_out),
    //out
    .spi_rd_data(spi_rd_data),
    .spi_MOSI(write_AD_data),
    .spi_rd_done(spi_rd_done),
    .spi_wr_done(spi_wr_done),
    .spi_sclk(sclk)
);

clk_div clk_fsm_1m(
    //in
    .sys_clk(sys_clk),
    .rst_n(rst_n),
    //out
    .clk_fsm(clk_fsm)
);






endmodule
