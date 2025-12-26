`timescale 1ns / 1ps

module UART_Periph(
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,

    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    // External Ports
    input  logic        rx,
    output logic        tx
    );

    logic TX_FIFO_EMPTY,TX_FIFO_FULL,RX_FIFO_EMPTY,RX_FIFO_FULL;
    logic TX_BUSY,TX_DONE,RX_BUSY,X_DONE;

    logic [7:0] FWDATA_TX;
    logic [7:0] FRDATA_RX;
    logic       TX_FIFO_PUSH;
    logic       RX_FIFO_POP;


    APB_SlaveIntf_UART U_APB_SlaveIntf_UART(
    .*,
    .TX_FIFO_SR({TX_FIFO_FULL,TX_FIFO_EMPTY}), // full,empty
    .RX_FIFO_SR({RX_FIFO_FULL,RX_FIFO_EMPTY}),
    .TX_SR({TX_DONE,TX_BUSY}),
    .RX_SR({RX_DONE,RX_BUSY})
);

    UART_FIFO U_UART_FIFO(
        .*,
        .RX_FIFO_EMPTY(RX_FIFO_EMPTY), // to apb intf
        .TX_FIFO_EMPTY(TX_FIFO_EMPTY), // to apb intf
        .RX_FIFO_FULL(RX_FIFO_FULL), // to apb intf
        .TX_FIFO_FULL(TX_FIFO_FULL), // to apb intf
        .TX_BUSY(TX_BUSY),
        .RX_BUSY(RX_BUSY),
        .TX_DONE(TX_DONE),
        .RX_DONE(RX_DONE)
        );



endmodule



module APB_SlaveIntf_UART (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    input  logic [ 1:0] TX_FIFO_SR, // full,empty
    input  logic [ 1:0] RX_FIFO_SR,
    input  logic [ 1:0] TX_SR,
    input  logic [ 1:0] RX_SR,
    output logic [ 7:0] FWDATA_TX,
    input  logic [ 7:0] FRDATA_RX,
    output logic        TX_FIFO_PUSH,
    output logic        RX_FIFO_POP
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;
    logic [31:0] slv_reg1_next;

    logic we_reg, we_next; // write signal : to uart
    logic re_reg, re_next; // read signal : to uart
    logic [31:0] PRDATA_reg, PRDATA_next;
    logic PREADY_reg, PREADY_next;

    assign TX_FIFO_PUSH = we_reg;
    assign RX_FIFO_POP = re_reg;

    typedef enum {
        IDLE,
        READ,
        WRITE,
        TDR_WRITE_WAIT
    } state_e;


    state_e state_reg, state_next;

    // SR (always, READ only)
    // slv_reg0[7:0] 
    //  = {RX_DONE, RX_BUSY,TX_DONE, TX_BUSY, RXF_FULL, RXF_EMPTY, TXF_FULL, TXF_EMPTY};
    assign slv_reg0[7:0] = {RX_SR,TX_SR,RX_FIFO_SR,TX_FIFO_SR} ;

    assign FWDATA_TX = slv_reg1[7:0];

    
    assign slv_reg2[7:0] = FRDATA_RX; 

    assign PRDATA = PRDATA_reg;
    assign PREADY = PREADY_reg;

    wire tx_full  = TX_FIFO_SR[1];

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0[31:8] <=0; //SR
            slv_reg1 <=0; //write
            slv_reg2[31:8] <=0; //read
            
            state_reg <= IDLE;
            we_reg    <= 0;
            re_reg    <= 0;
            PRDATA_reg <= 32'bx;
            PREADY_reg <= 1'b0;
        end else begin
            slv_reg1  <= slv_reg1_next;
            state_reg <= state_next;
            we_reg    <= we_next;
            re_reg    <= re_next;
            PRDATA_reg <= PRDATA_next;
            PREADY_reg <= PREADY_next;
        end
    end

    always_comb begin
        state_next = state_reg;
        slv_reg1_next = slv_reg1;
        we_next = we_reg;
        re_next = re_reg;
        PRDATA_next = PRDATA_reg;
        PREADY_next = PREADY_reg;

        case (state_reg)
            IDLE: begin
                
                PREADY_next = 1'b0;
                if (PSEL && PENABLE) begin
                    if (PWRITE) begin // write 
                        re_next = 1'b0;
                        we_next = 1'b0; 
                        PREADY_next  = 1'b1; 
                        state_next   = WRITE;
                        case (PADDR[3:2]) 
                            2'd0: ; // read only
                            2'd1: begin 
                                if (!tx_full) begin
                                slv_reg1_next = PWDATA;
                                PREADY_next  = 1'b0;  
                                state_next= TDR_WRITE_WAIT;
                            end else begin
                                PREADY_next  = 1'b0; 
                                state_next   = IDLE;
                            end
                            end
                            2'd2: ; // read only
                            2'd3: ; // read only
                        endcase
                    end else begin //read
                        state_next= READ;
                        PREADY_next = 1'b1;
                        we_next = 1'b0;
                        case (PADDR[3:2])
                            2'd0: begin
                                PRDATA_next = slv_reg0;
                                re_next = 1'b0;
                            end
                            2'd1: begin
                                PRDATA_next = slv_reg1;
                                re_next = 1'b0;
                            end
                            2'd2: begin
                                PRDATA_next = slv_reg2;
                                re_next = 1'b1;
                            end
                            2'd3: begin
                                PRDATA_next = {30'b0,we_reg, re_reg};
                                re_next = 1'b0;
                            end
                        endcase
                    end
                end
            end

            READ: begin
                re_next = 1'b0;
                we_next = 1'b0;
                PREADY_next = 1'b0;
                state_next = IDLE; 
            end
            TDR_WRITE_WAIT: begin
                if(PADDR[3:2]==2'd1) we_next =1'b1; // PUSH
                re_next = 1'b0;
                state_next = WRITE;
                PREADY_next = 1'b1;
            end
            WRITE: begin
                re_next = 1'b0;
                we_next = 1'b0;
                PREADY_next = 1'b0;
                state_next = IDLE; 
            end
        endcase
    end
endmodule




module UART_FIFO(
    input PCLK,
    input PRESET,
    input rx,
    input  [7:0]FWDATA_TX, // from apb intf
    input TX_FIFO_PUSH, // from apb intf
    input RX_FIFO_POP, // from apb intf
    output tx, // to pc
    output [7:0]FRDATA_RX, // to apb intf
    // RX
    output RX_FIFO_EMPTY, // to apb intf
    output RX_FIFO_FULL, // to apb intf
    output RX_DONE,
    output RX_BUSY,
    // TX
    output TX_FIFO_EMPTY,
    output TX_FIFO_FULL,
    output TX_DONE,
    output TX_BUSY
    );

    wire w_b_tick;
    wire w_rx_done, w_rx_busy;
    wire w_tx_done, w_tx_busy;
    wire [7:0] w_rx_data, w_tx_data;
    wire w_tx_empty;
    wire tx_start_pulse = (~w_tx_empty) & (~w_tx_busy); 
    wire tx_pop_pulse   = tx_start_pulse;
  


   
    assign TX_FIFO_EMPTY= w_tx_empty;
    assign TX_DONE = w_tx_done;
    assign TX_BUSY = w_tx_busy;
    assign RX_DONE = w_tx_done;
    assign RX_BUSY = w_tx_busy;

    tick_gen_16 U_BOARD_TICK_GEN (
    .clk(PCLK),
    .rst(PRESET),
    .b_16tick(w_b_tick)
    );

    uart_tx U_UART_TX(
    .clk(PCLK),
    .rst(PRESET),
    .b_16tick(w_b_tick),
    .start_trig(tx_start_pulse),
    .tx_data(w_tx_data),
    .tx(tx),
    .tx_busy(w_tx_busy),
    .tx_done(w_tx_done)
    );

    fifo U_TX_FIFO(
    .clk(PCLK),
    .rst(PRESET),
    .push_data(FWDATA_TX),
    .push(TX_FIFO_PUSH), // write신호
    .pop(tx_pop_pulse),
    .pop_data(w_tx_data), // to tx-> pc
    .full(TX_FIFO_FULL), // to kit
    .empty(w_tx_empty)
    );

    uart_rx U_UART_RX(
    .clk(PCLK),
    .rst(PRESET),
    .b_16tick(w_b_tick),
    .rx(rx),
    .rx_data(w_rx_data),
    .rx_done(w_rx_done),
    .rx_busy(w_rx_busy)

    );
    
    fifo U_RX_FIFO(
    .clk(PCLK),
    .rst(PRESET),
    .push_data(w_rx_data),
    .push(w_rx_done),
    .pop(RX_FIFO_POP), //  read 신호
    .pop_data(FRDATA_RX), // to kit and tx
    .full(RX_FIFO_FULL),
    .empty(RX_FIFO_EMPTY) // to kit and tx
    );

   

endmodule



module tick_gen_16(
    input  clk,
    input  rst,
    output b_16tick
    );

    parameter BAUDRATE = 9600*16 ;
    localparam BAUD_COUNT = 100_000_000/BAUDRATE;
    reg [$clog2(BAUD_COUNT)-1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;

    //output

    assign b_16tick = tick_reg ;


    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count_reg <= 0;
            tick_reg <=0;
        end
        else begin
            count_reg <= count_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        tick_next = 1'b0;

        if(count_reg == BAUD_COUNT-1) begin
            count_next = 0;
            tick_next  =1'b1;
        end
        else begin
            count_next = count_reg +1;
            tick_next  =1'b0;
        end
     end

endmodule


