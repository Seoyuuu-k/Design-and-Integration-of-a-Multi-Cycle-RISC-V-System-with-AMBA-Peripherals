`timescale 1ns / 1ps

module GPI_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,

    // APB Interface Signals
    input  logic [ 2:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    // External Ports
    input  logic [ 7:0] gpi
);

    logic [7:0] cr;
    logic [7:0] idr;

    APB_SlaveIntf_GPI U_APB_SlaveIntf_GPI (.*);
    GPI U_GPI (.*);

endmodule


module  APB_SlaveIntf_GPI (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 2:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    //internal Port
    output logic [7:0]  cr, // reg 0
    input  logic [7:0]  idr // reg1 (MCU 외부에서 들어온값!)
);
    logic [31:0] slv_reg0, slv_reg1;

    assign cr = slv_reg0[7:0];
    // 1)  wire로 연결헤서 read
   // assign slv_reg1 = {24'b0, idr}; // input idr 값이 slv_reg1로 저장된후 raad

    //paddr[2] 1일때 저장금지!
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
            
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[2])
                        1'd0: slv_reg0 <= PWDATA;
                        1'd1: ; // 1일때 저장금지!, read only
                    endcase
                end else begin
                    case (PADDR[2])
                        1'd0: PRDATA <= slv_reg0;
                        //2'd1: PRDATA <= slv_reg1;

                        // 2) 그냥 바로
                         1'd1: PRDATA <= {24'b0, idr};
                    endcase

                end
            end
        end
    end
endmodule


module GPI (
    input  logic [7:0] cr,
    output logic [7:0] idr,
    input logic [7:0] gpi
);


    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign idr[i] = cr[i] ? gpi[i] : 1'bz;
        end
    endgenerate


endmodule

