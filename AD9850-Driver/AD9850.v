`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: JLU
// Engineer: lyjslay@liuyijun
// 
// Create Date: 2021/10/20 12:56:21
// Design Name: 
// Module Name: AD9850
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


module AD9850(
    input sys_clk,
    input rst_n,
    //input update_ctrl_data,//外部给出的标志信号,是否要更新控制字
    output AD9850_fq_ud,//AD9850的load信号,上升沿时将5*8bit控制字装载,并将指针指向第一个寄存器
    output [7:0] AD9850_ctrl_data,//共40bit,分5次load
    output AD9850_clk,//芯片的外部时钟,每个上升沿将8bit数据写入并将指针移至下一个寄存器
    output AD9850_rst//芯片的复位脚
    //output AD9850_setdone //完成设置的标志,不用输出给DDS模块
    );

    wire update_ctrl_data;
    assign update_ctrl_data = 1;
    wire AD9850_setdone;
    



    /*
    **定时器延时,复位信号使用,高电平5clk,低电平8clk,才能成功复位
    **详情参考数据手册11页
    */
    parameter HIGH_CNT = 5;
    parameter LOW_CNT = 8;
    reg high_cnt_en;//计数器使能,在AD9850_INIT状态中使能
    reg low_cnt_en;
    reg [2:0] rst_high_cnt;
    reg [2:0] rst_low_cnt;
    wire rst_high_done;//rst高电平保持5个周期结束标志
    wire rst_low_done;//低电平8周期结束标志

    always@(posedge sys_clk) begin
        if(!high_cnt_en)begin
            rst_high_cnt <= 3'd0;
        end
        else begin
            rst_high_cnt <= rst_high_cnt + 3'd1;
        end
    end
    always@(posedge sys_clk) begin
        if(!low_cnt_en)begin
            rst_low_cnt <= 3'd0;
        end
        else begin
            rst_low_cnt <= rst_low_cnt + 3'd1;
        end
    end
    assign rst_high_done = (rst_high_cnt == HIGH_CNT - 1)? 1 : 0;
    assign rst_low_done = (rst_low_cnt == LOW_CNT - 1)? 1 : 0;


    reg [5:0] cnt_1us;
    parameter CNT1US = 50;//50*0.02us = 1us

    always@(posedge sys_clk) begin
        if(!rst_n)begin
            cnt_1us <= 0;
        end
        else if(cnt_1us == CNT1US - 1) begin
            cnt_1us <= 0;
        end
        else begin
            cnt_1us <= cnt_1us + 1;
        end
    end




    /*
    **状态机控制通信,初始化,五个字节控制字的发送
    */
    parameter IDLE = 15'b100_0000_0000_0000;
    parameter AD9850_INIT = 15'b000_0000_0000_0001;
    parameter AD9850_INIT_DONE = 15'b000_0000_0000_0010;
    parameter AD9850_W0 = 15'b000_0000_0000_0100;
    parameter AD9850_W0_WAIT = 15'b000_0000_0000_1000;
    parameter AD9850_W1 = 15'b000_0000_0001_0000;
    parameter AD9850_W1_WAIT = 15'b000_0000_0010_0000;
    parameter AD9850_W2 = 15'b000_0000_0100_0000;
    parameter AD9850_W2_WAIT = 15'b000_0000_1000_0000;
    parameter AD9850_W3 = 15'b000_0001_0000_0000;
    parameter AD9850_W3_WAIT = 15'b000_0010_0000_0000;
    parameter AD9850_W4 = 15'b000_0100_0000_0000;
    parameter AD9850_W4_WAIT = 15'b000_1000_0000_0000;
    parameter AD9850_LOAD = 15'b001_0000_0000_0000;
    parameter AD9850_LOAD_DONE = 15'b010_0000_0000_0000;

    
    reg [15:0] current_state;
    reg [15:0] next_state;
    reg fq_ud_reg;
    reg w_clk_reg;
    reg rst_reg;
    reg [7:0] ctrl_data_reg;
    reg set_ctrl_data_done;//完成设置控制字的标志
    reg [4:0] pahse_ctrl_data = 5'b0_0000;
    reg [31:0] freq_ctrl_data = 32'b1000_0110_0011_1000; //1KHz(1000/0.0291)

    assign AD9850_clk = w_clk_reg;
    assign AD9850_fq_ud = fq_ud_reg;
    assign AD9850_rst = rst_reg; 
    assign AD9850_ctrl_data = ctrl_data_reg;
    assign AD9850_setdone = set_ctrl_data_done;

    always@(posedge sys_clk) begin
        if(!rst_n)begin
            current_state <= AD9850_INIT;
        end
        else begin
            current_state <= next_state;
        end
    end

    always@(*) begin
        high_cnt_en = 0;
        low_cnt_en = 0;
        case(current_state)
            AD9850_INIT:begin
                high_cnt_en = 1;//rst高电平5clk
                if(rst_high_done) begin
                    next_state = AD9850_INIT_DONE;
                end
                else begin
                    next_state = AD9850_INIT;
                end
            end
            AD9850_INIT_DONE:begin
                low_cnt_en = 1;//rst高电平8clk
                if(rst_low_done) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = AD9850_INIT_DONE;
                end
            end
            IDLE: begin
                if(update_ctrl_data) begin//外部标志信号需要更新控制字
                    next_state = AD9850_W0;
                end
                else begin
                    next_state = IDLE;
                end
            end
            AD9850_W0: next_state = AD9850_W0_WAIT;
            AD9850_W0_WAIT: next_state = AD9850_W1;
            AD9850_W1: next_state = AD9850_W1_WAIT;
            AD9850_W1_WAIT: next_state = AD9850_W2;
            AD9850_W2: next_state = AD9850_W2_WAIT;
            AD9850_W2_WAIT: next_state = AD9850_W3;
            AD9850_W3: next_state = AD9850_W3_WAIT;
            AD9850_W3_WAIT: next_state = AD9850_W4;
            AD9850_W4: next_state = AD9850_W4_WAIT;
            AD9850_W4_WAIT: next_state = AD9850_LOAD;
            AD9850_LOAD: next_state = AD9850_LOAD_DONE;
            AD9850_LOAD_DONE: next_state = IDLE;
            default: next_state = AD9850_INIT;
        endcase   
    end


    always @(posedge sys_clk) begin
        if(!rst_n) begin
            fq_ud_reg <= 0;
            w_clk_reg <= 0;
            rst_reg <= 0;
            ctrl_data_reg <= 0;
        end
        else begin
            case(current_state)
                AD9850_INIT:begin //rst高电平5clk
                    fq_ud_reg <= 0;
                    w_clk_reg <= 0;
                    rst_reg <= 1;
                    set_ctrl_data_done <= 0;
                end
                AD9850_INIT_DONE:begin //rst低电平8clk
                    fq_ud_reg <= 0;
                    w_clk_reg <= 0;
                    rst_reg <= 0;
                    set_ctrl_data_done <= 0;
                end
                IDLE: begin
                    fq_ud_reg <= 0;
                    w_clk_reg <= 0;
                    rst_reg <= 0;
                    set_ctrl_data_done <= 0;
                end
                AD9850_W0: begin
                    w_clk_reg <= 0;
                    ctrl_data_reg <= {pahse_ctrl_data,3'b000};//相位控制字[7:3],低功耗[2:2],厂家保留字[1:0]
                end
                AD9850_W0_WAIT: w_clk_reg <= 1;//上升沿传递一个字节
                AD9850_W1: begin
                    w_clk_reg <= 0;
                    ctrl_data_reg <= freq_ctrl_data[31:24];
                end
                AD9850_W1_WAIT: w_clk_reg <= 1;//上升沿传递一个字节
                AD9850_W2: begin
                    w_clk_reg <= 0;
                    ctrl_data_reg <= freq_ctrl_data[23:16];
                end
                AD9850_W2_WAIT: w_clk_reg <= 1;//上升沿传递一个字节
                AD9850_W3: begin
                    w_clk_reg <= 0;
                    ctrl_data_reg <= freq_ctrl_data[15:8];
                end
                AD9850_W3_WAIT: w_clk_reg <= 1;//上升沿传递一个字节
                AD9850_W4: begin
                    w_clk_reg <= 0;
                    ctrl_data_reg <= freq_ctrl_data[7:0];
                end
                AD9850_W4_WAIT: w_clk_reg <= 1;//上升沿传递一个字节
                AD9850_LOAD: begin
                    w_clk_reg <= 0;
                    fq_ud_reg <= 0;//这里暂时不拉高因为Tfd的要求,上身沿必须在w_clk上升沿后7ns
                end
                AD9850_LOAD_DONE: begin
                    fq_ud_reg <= 1;//上升沿将5次循环的40bit装载进芯片
                    set_ctrl_data_done <= 1;
                end
                default:;
            endcase
        end
    end





endmodule
