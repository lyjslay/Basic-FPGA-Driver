`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/09/18 11:03:40
// Design Name: 
// Module Name: measure_cotr
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


module measure_cotr
(
    input           clk_sys,
    input           clk_samp,//1M分频时钟
    input           rst_n,
    input [11:0]    AD_data,
    output [1:0]    cotr_sig,
    output  [23:0]  data_out
);
parameter          Vrms_gata = 22'd13141;
reg [1:0]           cotr_sig_buf;
wire                measure_done_buf;
wire [21:0]         measure_data;
reg [23:0]          data_out_buf;
reg  [2:0]          state;
reg                 measure_start;
reg                 measure_done;



always@(posedge clk_sys) begin
    measure_done <= measure_done_buf;
end

always@(posedge clk_sys) begin
    if(!rst_n)
    begin
        state <= 3'd0;
        cotr_sig_buf <= 2'd0;
        measure_start <= 1'b0;
        data_out_buf <= 24'd0;
    end
    else
    begin
        case(state)
            3'd0:begin 
                measure_start <= 1'b0; 
                state <= 3'd1; 
            end
            3'd1:begin 
                cotr_sig_buf <= 2'b00; 
                measure_start <= 1'b1; 
                state <= 3'd2; 
            end
            3'd2:begin 
                measure_start <= 1'b0; 
                if(measure_done)begin 
                    if(measure_data>=Vrms_gata) begin 
                        data_out_buf <= {2'b00,measure_data}; 
                        state <= 3'd0; 
                    end 
                    else state <= 3'd3; 
                end 
             end
            3'd3:begin 
                cotr_sig_buf <= 2'b01; 
                measure_start <= 1'b1; 
                state <= 3'd4; 
            end
            3'd4:begin 
                measure_start <= 1'b0; 
                if(measure_done)begin 
                    if(measure_data>=Vrms_gata) begin 
                        data_out_buf <= {2'b00,measure_data}; 
                        state <= 3'd0; 
                    end 
                    else state <= 3'd5; 
                end 
            end
            3'd5:begin 
                cotr_sig_buf <= 2'b10; 
                measure_start <= 1'b1; 
                state <= 3'd6; 
            end
            3'd6:begin 
                measure_start <= 1'b0; 
                if(measure_done)begin 
                    data_out_buf <= {2'b10,measure_data};  
                    state <= 3'd0; 
                end 
            end
        endcase
    end
end
    measure measure_inst
    (
    .clk_sys(clk_sys),
    .clk_samp(clk_samp),
    .rst_n(rst_n),
    .mearsure_start(measure_start),
    .AD_data(AD_data),
    .measure_done_q(measure_done_buf),
    .data_out(measure_data)
    );
    assign data_out = data_out_buf;
    assign cotr_sig = cotr_sig_buf;
endmodule
