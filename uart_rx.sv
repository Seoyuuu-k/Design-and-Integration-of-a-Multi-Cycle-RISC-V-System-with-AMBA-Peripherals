`timescale 1ns / 1ps



module uart_rx(
    input clk,
    input rst,
    input rx,
    input b_16tick,
    output[7:0]rx_data,
    output rx_done,
    output rx_busy
    );


    // tick_gen_16 U_GEN_16_TICK (
    // .clk(clk),
    // .rst(rst),
    // .b_16tick(b_16tick)
    // );


    parameter IDLE =2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;
    reg [1:0] current_state, next_state;

    reg rx_done_r, rx_done_n;
    reg rx_busy_r, rx_busy_n;
    
    reg [4:0] b_16tick_cnt_r, b_16tick_cnt_n; //max 23
    reg [2:0] data_cnt_r, data_cnt_n; //max 7

    reg [7:0] rx_data_buf, rx_data_n;

    //output

    assign rx_data = rx_data_buf;
    assign rx_done = rx_done_r;
    assign rx_busy = rx_busy_r;


    always @(posedge clk, posedge rst) begin
        if(rst)begin
            current_state <= IDLE;
            rx_done_r     <= 0;
            rx_busy_r     <= 0;
            data_cnt_r    <= 0;
            b_16tick_cnt_r <= 0;
            rx_data_buf    <= 0;
        end else begin
            current_state <= next_state;
            rx_done_r     <= rx_done_n;
            rx_busy_r     <= rx_busy_n;
            data_cnt_r    <= data_cnt_n;
            b_16tick_cnt_r <= b_16tick_cnt_n;
            rx_data_buf    <= rx_data_n;
        end
    end

    always @(*) begin
        next_state = current_state;
        rx_done_n  = rx_done_r;
        rx_busy_n  = rx_busy_r;
        data_cnt_n = data_cnt_r;
        b_16tick_cnt_n = b_16tick_cnt_r;
        rx_data_n      = rx_data_buf;


        case (current_state)
           IDLE : begin
            rx_busy_n = 1'b0; // 안전하게 IDLE상태로 온 다음클락에 0으로
            rx_done_n =1'b0; 
                if(rx==0)begin
                    next_state = START;
                    rx_busy_n = 1'b1;
                    
                end
           end
           START : begin
                if(b_16tick)begin
                    if(b_16tick_cnt_r==23)begin
                        b_16tick_cnt_n =0;
                        next_state = DATA;
                    end else begin
                        b_16tick_cnt_n = b_16tick_cnt_r +1;
                    end
                end 
           end
           DATA : begin
                if(b_16tick)begin
                    
                    if(b_16tick_cnt_r==0)begin
                        rx_data_n[7] =rx;
                    end

                    if(b_16tick_cnt_r==15) begin
                        b_16tick_cnt_n =0;
                        if(data_cnt_r ==7) begin
                            data_cnt_n =0;
                            next_state = STOP;
                        end else begin
                            data_cnt_n = data_cnt_r +1;
                            rx_data_n = rx_data_buf >> 1;
                        end
                    end else begin
                        b_16tick_cnt_n = b_16tick_cnt_r +1;
                    end


                end 
           end
           STOP : begin            
                if(b_16tick) begin
                    next_state =IDLE; // next 바로 그냥 준비상태로~
                    rx_done_n =1;
                end

           end
        endcase
    end
endmodule



// module tick_gen_16(
//     input  clk,
//     input  rst,
//     output b_16tick
//     );

//     parameter BAUDRATE = 9600*16 ;
//     localparam BAUD_COUNT = 100_000_000/BAUDRATE;
//     reg [$clog2(BAUD_COUNT)-1 : 0] count_reg, count_next;
//     reg tick_reg, tick_next;

//     //output

//     assign b_16tick = tick_reg ;


//     always @(posedge clk, posedge rst) begin
//         if(rst) begin
//             count_reg <= 0;
//             tick_reg <=0;
//         end
//         else begin
//             count_reg <= count_next;
//             tick_reg <= tick_next;
//         end
//     end

//     always @(*) begin
//         count_next = count_reg;
//         tick_next = 1'b0;

//         if(count_reg == BAUD_COUNT-1) begin
//             count_next = 0;
//             tick_next  =1'b1;
//         end
//         else begin
//             count_next = count_reg +1;
//             tick_next  =1'b0;
//         end
//      end

// endmodule