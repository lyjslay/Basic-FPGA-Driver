`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: JLU
// Engineer: lyjslay
// 
// Create Date: 2021/10/18 15:47:25
// Design Name: 
// Module Name: FFT_IP
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


module FFT_IP(
    input sys_clk,
    input rst_n,
    input start_sig,
    input [15:0] dds_data,//DDS输入的待处理的数据

    output [15:0] fft_real,//fft输出的实部
    output [15:0] fft_imag,//虚部
    output [32:0] fft
    );





    /*
    **1024点的fft,每个信号的含义和配置在数据手册第三章
    */
    wire aclk;
    //配置Channel
    wire [23:0] s_axis_config_tdata;//配置模式,可在Vivado IP配置页面的Implementation Detail里查看详情,这里令其为1使用fft
    wire s_axis_config_tvalid;//外部给出,标志配置数据有效,为1即可
    wire s_axis_config_tready;//CORE准备好接受配置数据
    assign s_axis_config_tdata = 24'd1;//使用FFT模式(0表示ifft)
    assign s_axis_config_tvalid = 1;//输入数据始终有效
    //输入Channel,由下面的always块生成
    wire [31:0] s_axis_data_tdata;//输入数据的[虚部,实部],这里从DDS那里获取
    wire s_axis_data_tvalid;
    wire s_axis_data_tready;
    wire s_axis_data_tlast;//仅在1024个点输入期间,由外部输入高,用于抛出ENVET事件

    //输出Channel
    wire [31:0] m_axis_data_tdata;//输出频谱的[虚部,实部]
    wire [15:0] m_axis_data_tuser;//这里只配置使用了XK_INDEX,由于是1024点的,故索引有10bit[9:0]
    wire m_axis_data_tvalid;
    wire m_axis_data_tready;
    wire m_axis_data_tlast;  
    assign fft_real = m_axis_data_tdata[15:0];
    assign fft_imag = m_axis_data_tdata[31:16];
    //assign fft = m_axis_data_tdata[15:0] * m_axis_data_tdata[15:0] + m_axis_data_tdata[31:16] * m_axis_data_tdata[31:16];
    assign m_axis_data_tready = 1;//时刻都准备接受输出

    wire [31:0] real_square;
    wire [31:0] imag_square;
    assign fft = real_square + imag_square;



    mult_gen_0 imag (
        .CLK(sys_clk),  // input wire CLK
        .A(fft_imag),      // input wire [15 : 0] A
        .B(fft_imag),      // input wire [15 : 0] B
        .P(imag_square)      // output wire [31 : 0] P
    );

    mult_gen_0 squre(
        .CLK(sys_clk),  // input wire CLK
        .A(fft_real),      // input wire [15 : 0] A
        .B(fft_real),      // input wire [15 : 0] B
        .P(real_square)      // output wire [31 : 0] P
    );

    


    //一些事件标志运行状态
    wire event_frame_started;
    wire event_tlast_unexpected;
    wire event_tlast_missing;
    wire event_status_channel_halt;
    wire event_data_in_channel_halt;
    wire event_data_out_channel_halt;




    /*
    **1.生成100kHz的时钟,驱动fftCORE
    **2.DDS输入的数据计数,计够1024个点,设置s_axis_data_tlast信号
    */
    parameter cnt_500ns = 25;//25*0.02us=0.5us
    reg [8:0] aclk_1m_cnt;
    reg aclk_1m;//可以认为是采样频率,满足Nyquist定律
    assign aclk = aclk_1m;
    always@(posedge sys_clk) begin
        if(!rst_n)begin
            //input_cnt <= 0;
            aclk_1m_cnt <= 0;
            aclk_1m <= 0;       
        end
        else if(aclk_1m_cnt == cnt_500ns-9'd1) begin
            aclk_1m <= ~aclk_1m;
            aclk_1m_cnt <= 9'd0;
        end
        else begin
            aclk_1m_cnt <= aclk_1m_cnt + 9'd1;
        end
    end


    reg fft_input_busy;//由start_sig生成,输入N个点之间一直拉高
    reg [15:0] fft_input_cnt;//输入数据的计数
    reg fft_input_last;//最后一个输入的标志
    reg fft_input_valid;
    reg [31:0] fft_input_data;
    parameter FFT_N = 1024 ;

    assign s_axis_data_tdata = fft_input_data;//输入数据虚部为0
    assign s_axis_data_tvalid = fft_input_valid;//输入数据始终有效
    assign s_axis_data_tlast = fft_input_last;//从上边的always block生成
    always@(posedge sys_clk) begin
        if(!rst_n)begin
            fft_input_busy <= 1'd0;
            fft_input_cnt <= 10'd0;
            fft_input_last <= 1'd0;
            fft_input_valid <= 1'd0;
            fft_input_data <= 32'd0;
        end
        else if(start_sig) begin//检测到开始信号,busy拉高
            fft_input_busy <= 1;
            fft_input_cnt <= 0;//计数清零
        end
        else if(!start_sig && fft_input_busy && s_axis_data_tready) begin //接收到开始信号的下一周期,且FFTCore准备好接收数据
            if(aclk_1m_cnt == cnt_500ns-9'd1 && aclk_1m == 0) begin//等待到aclk_1m上身沿触发
                if(fft_input_cnt == FFT_N - 1)begin//最后一个数据
                    fft_input_valid <= 1'b1;
                    fft_input_last <= 1'b1;//最后一个数的标志
                    fft_input_data <= {16'd0,dds_data};
                    //fft_input_cnt <= 0;//计数清零
                    fft_input_busy <= 1'd0;//输入完成busy被拉低,下一个sys_clk便不会进入该分支	 
                end
                else begin //1~N-1的数据
                    fft_input_valid <= 1'b1;//输入数据有效
                    fft_input_cnt <= fft_input_cnt + 1;//输入数据计数
                    fft_input_last <= 1'b0;//不是最后一个数
                    fft_input_data <= {16'd0,dds_data};
                    fft_input_busy <= 1'd1;
                end
            end
        end
        else begin //没有等到开始信号,或是输入完成busy被拉低,数据一直无效
            if(aclk_1m_cnt == cnt_500ns-9'd1 && aclk_1m == 0) begin
                fft_input_valid <= 1'b0;
                fft_input_cnt <= 10'd0;
                fft_input_last <= 1'b0;
                fft_input_data <= fft_input_data;
            end
        end
    end







    xfft_0 fft_1024 (
        .aclk(aclk),// input wire aclk    
        //configure channel                                            
        .s_axis_config_tdata(s_axis_config_tdata),                  // input wire [23 : 0] s_axis_config_tdata
        .s_axis_config_tvalid(s_axis_config_tvalid),                // input wire s_axis_config_tvalid
        .s_axis_config_tready(s_axis_config_tready),                // output wire s_axis_config_tready
        //input channel
        .s_axis_data_tdata(s_axis_data_tdata),                      // input wire [31 : 0] s_axis_data_tdata
        .s_axis_data_tvalid(s_axis_data_tvalid),                    // input wire s_axis_data_tvalid
        .s_axis_data_tready(s_axis_data_tready),                    // output wire s_axis_data_tready
        .s_axis_data_tlast(s_axis_data_tlast),                      // input wire s_axis_data_tlast
        //output channel
        .m_axis_data_tdata(m_axis_data_tdata),                      // output wire [31 : 0] m_axis_data_tdata
        .m_axis_data_tuser(m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
        .m_axis_data_tvalid(m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
        .m_axis_data_tready(m_axis_data_tready),                    // input wire m_axis_data_tready
        .m_axis_data_tlast(m_axis_data_tlast),                      // output wire m_axis_data_tlast
        //EVENT Channel不连接时综合工具会自动将其删除
        .event_frame_started(event_frame_started),                  // output wire event_frame_started
        .event_tlast_unexpected(event_tlast_unexpected),            // output wire event_tlast_unexpected
        .event_tlast_missing(event_tlast_missing),                  // output wire event_tlast_missing
        .event_status_channel_halt(event_status_channel_halt),      // output wire event_status_channel_halt
        .event_data_in_channel_halt(event_data_in_channel_halt),    // output wire event_data_in_channel_halt
        .event_data_out_channel_halt(event_data_out_channel_halt)  // output wire event_data_out_channel_halt
    );
endmodule
