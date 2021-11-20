`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/27 17:31:43
// Design Name: 
// Module Name: EC11
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


module EC11(
    input sys_clk,
    input rst_n,
    input key_a,//A管脚(模块上的CLK脚)
    input key_b,//B管脚(模块上的DT脚)
    input key_sw,//D管脚（模块上的SW脚）

    output Left_pulse_q,//左旋转脉冲输出
    output Right_pulse_q,//右旋转脉冲输出
    output SW_pulse,	//按动脉冲输出
    output [3:0] led_q
);
 
    parameter cnt_500us = 25000;//0.02us*25000 = 500us	
 
    //计数器周期为500us，控制采样频率
    reg	[16:0] cnt; 
    always@(posedge sys_clk) begin
        if(!rst_n) begin
            cnt <= 0;
        end
        else if(cnt == cnt_500us-1) begin
            cnt <= 0;
        end
        else begin
            cnt <= cnt + 1;
        end
    end
 
    reg	[5:0] cnt_20ms;//计时20ms
    reg	key_a_r,key_a_r1;
    reg	key_b_r,key_b_r1;
    reg	key_sw_r,key_sw_r1;
    //A、B、D脚去抖
    always@(posedge sys_clk) begin
        if(!rst_n) begin
            key_a_r	<= 1'b1;
            key_a_r1 <=	1'b1;
            key_b_r	<= 1'b1;
            key_b_r1 <=	1'b1;
            cnt_20ms <=	1'b1;
            key_sw_r <=	1'b1;
        end 
        else if(cnt == cnt_500us-1) begin//AB信号500us采样
            key_a_r	<= key_a;
            key_a_r1 <=	key_a_r;
            key_b_r	<= key_b;
            key_b_r1 <=	key_b_r;
            if(cnt_20ms >= 6'd40) begin	//D信号20ms采样,40*cnt_500us = 20ms
                cnt_20ms <= 6'd0;
                key_sw_r <= key_sw;
            end 
            else begin 
                cnt_20ms <= cnt_20ms + 1'b1;
                key_sw_r <=	key_sw_r;
            end
        end
    end
 

    always@(posedge sys_clk) begin
        if(!rst_n) begin
            // key_a_r1 <=	1'b1;
            // key_b_r1 <=	1'b1;
            key_sw_r1 <= 1'b1;
        end
        else begin
            // key_a_r1 <=	key_a_r;
            // key_b_r1 <=	key_b_r;
            key_sw_r1 <= key_sw_r;
        end
    end
 
    wire A_state = key_a_r1 && key_a_r && key_a;	//A脚高电平状态检测
    wire B_state = key_b_r1 && key_b_r && key_b;	//B
    assign SW_pulse = key_sw_r1 && (!key_sw_r);		//检测D下降沿脉冲输出
 
    reg	A_state_reg;
    //A延迟一个时钟周期
    always@(posedge sys_clk) begin
        if(!rst_n) begin
            A_state_reg <= 1'b1;
        end 
        else begin
            A_state_reg <= A_state;
        end
    end
    
    //A上升下降沿检测
    wire A_pos = (!A_state_reg) && A_state;
    wire A_neg = A_state_reg && (!A_state);
    
    //AB信号组合判断EC11的操作并输出脉冲
    reg Left_pulse;
    reg Right_pulse;
    always@(posedge sys_clk)begin
        if(!rst_n)begin
            Right_pulse <= 1'b0;
            Left_pulse <= 1'b0;
        end else begin
            if(A_pos && B_state) begin
                Left_pulse <= 1'b1;	
            end
            else if(A_neg && B_state) begin
                Right_pulse <= 1'b1;
            end
            else begin
                Right_pulse <= 1'b0;
                Left_pulse <= 1'b0;
            end
        end
    end
    assign Left_pulse_q = Left_pulse;
    assign Right_pulse_q = Right_pulse;

    
    
    //测试用,编码器控制流水灯
    reg [3:0] led = 4'b0001;
    always @(posedge sys_clk ) begin
        if(!rst_n) begin
            led <= 0;
        end
        else begin
            if(Left_pulse) begin
                led <= {led[2:0],led[3]};
            end
            else if(Right_pulse) begin
                led <= {led[0],led[3:1]};
            end
            else if(SW_pulse) begin
                led <= ~led;
            end
            else begin
                led <= led;
            end
        end
    end
    assign led_q = led;

    //assign led_q = (Left_pulse) ? 3'b001 : (Right_pulse) ? 3'b010 : (SW_pulse) ? 3'b100 : 3'b000;
    


    // ila_0 ec11_monitor (
	// .clk(sys_clk), // input wire clk
	// .probe0(Left_pulse_q), // input wire [0:0]  probe0  
	// .probe1(Right_pulse_q), // input wire [0:0]  probe1 
	// .probe2(SW_pulse) // input wire [0:0]  probe2
    // );
 
endmodule