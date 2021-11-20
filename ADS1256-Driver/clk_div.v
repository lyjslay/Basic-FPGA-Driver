`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/28 20:17:15
// Design Name: 
// Module Name: clk_div
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


module clk_div(
    input sys_clk,
    input rst_n,
    output clk_fsm
    );
    
    parameter DIVIDE_FACTOR = 24;//50M -> 1M

    reg [4:0] cnt;
    reg clk_fsm_reg;
    assign clk_fsm = clk_fsm_reg;

    always @(posedge sys_clk) begin
        if(!rst_n) begin
            cnt <= 5'd0;
        end
        else begin
            cnt <= (cnt == DIVIDE_FACTOR) ? 5'd0 : (cnt + 5'd1);
        end
    end

    always @(posedge sys_clk) begin
        if(!rst_n) begin
            clk_fsm_reg <= 1'b1;
        end
        else begin
            clk_fsm_reg <= (cnt == DIVIDE_FACTOR) ? (~clk_fsm_reg) : clk_fsm_reg;
        end
    end

endmodule
