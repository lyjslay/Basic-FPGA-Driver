module peak_m (
    input   sys_clk,
    input   sys_rstn,
    input   [11:0]data_in,
    input   sig,   
    output  reg capture,
    output  reg [11:0]data_out
);
    //算法参数 
    parameter volt_threshold = 12'h7f8;//电压阈值7f8
    parameter counter_threshold = 8'd15;//脉冲宽度阈值
    parameter Static_voltage =12'h800;
    reg [11:0]minval_reg;
    reg [7:0]counter_reg;
    reg [11:0]half_peak;

    assign  half_peak=minval_reg+(11'h3ff^minval_reg[11:1]);
    //状态机参数
    parameter  IDLE=2'd0,FINDING=2'd1,CAPTURE=2'd2;
    reg [1:0]state,next_state;
    //状态改变
    always @(posedge sys_clk or negedge sys_rstn) begin
        if(~sys_rstn)state<=IDLE;
        else    state<=next_state;
    end
    //状态机输入
    always @(*) begin
        case(state)
            IDLE:begin
                if(sig)begin
                    if(data_in<volt_threshold)  next_state=FINDING;
                    else    next_state=IDLE;
                end
                else    next_state=IDLE;
            end
            FINDING:begin
                if(sig) begin
                    if(data_in>=half_peak)begin
                        if(counter_reg<=counter_threshold) next_state=IDLE;
                        else    next_state=CAPTURE;
                    end
                    else   next_state=FINDING; 
                end
                else    next_state=FINDING;
            end
            CAPTURE:begin
                next_state=IDLE;
            end
            default:next_state=IDLE;
        endcase
    end
    //状态机输出
    always @(posedge sys_clk or negedge sys_rstn) begin
        if(~sys_rstn)begin
            counter_reg<=0;
            minval_reg<=Static_voltage; 
            capture<=0;           
        end
        else begin
            case(next_state)
                IDLE:begin
                    counter_reg<=0;
                    minval_reg<=Static_voltage;
                    capture<=0;
                end
                FINDING:begin
                    if(sig)begin
                        if(data_in<minval_reg)begin
                            minval_reg<=data_in;
                        end
                        counter_reg<=counter_reg+1;
                    end
                end
                CAPTURE:begin
                    capture<=1;
                    data_out<=16'h800-minval_reg;
                end
            endcase
        end
    end

endmodule