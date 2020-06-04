// +FHDR------------------------------------------------------------
//                 Copyright (c) 2020 .
//                       ALL RIGHTS RESERVED
// -----------------------------------------------------------------
// Filename      : ahb_master.v
// Author        : 
// Created On    : 2020-03-12 06:30
// Last Modified : 
// -----------------------------------------------------------------
// Description:
//
//
// -FHDR------------------------------------------------------------
module ahb_master(hbusreq_o,
                haddr_o,
                htrans_o,
                hwdata_o,
                hwrite_o,
                hclk_i,
                irst_n,
                hgrant_i,
                hready_i,
                hrdata_i,
                we_i,
                re_i);
    
    input  hclk_i,irst_n,we_i,re_i,hgrant_i,hready_i;
    input  [31:0] hrdata_i;
    output hbusreq_o,hwrite_o;
    output [31:0] hwdata_o;
    output [1:0] htrans_o;
    output [31:0] haddr_o;
    
    reg [1:0] main_fsm_r;
    reg [2:0] rd_fsm_r;
    reg [2:0] wr_fsm_r;
    reg  [31:0 haddr_r;
    reg [2:0] rd_cnt_r;
    reg [2:0] wr_cnt_r;
    
    parameter  data_size    = 4; 
    parameter rd_base_addr  = 'h1A00;
    parameter  wr_base_addr = 'h1B00;
    
    //the status of main fsm
    parameter    S0 = 'd0;
    parameter    S1 = 'd1;
    parameter    S2 = 'd2;
    
    //the status of read fsm
    parameter  RD_IDLE   = 3'b000;
    parameter  RD_BUSREQ = 3'b001;
    parameter  RD_ADDR   = 3'b010;
    parameter  RD_RD     = 3'b011;
    parameter  RD_LRD    = 3'b100;
    
    wire   fsm_rd_idle   = rd_fsm_r == RD_IDLE;
    wire   fsm_rd_busreq = rd_fsm_r == RD_BUSREQ;
    wire   fsm_rd_addr   = rd_fsm_r == RD_ADDR;
    wire   fsm_rd_rd     = rd_fsm_r == RD_RD;
    wire   fsm_rd_lrd    = rd_fsm_r == = RD_LRD;
    wire    rd_last_data = rd_cnt_r == data_size - 1'd1;
    
    //the status of write fsm
    parameter  WR_IDLE   = 3'b000;
    parameter  WR_BUSREQ = 3'b001;
    parameter  WR_ADDR   = 3'b010;
    parameter  WR_WD     = 3'b011;
    parameter  WR_LWD    = 3'b100;
    
    wire   fsm_wr_idle   = wr_fsm_r == WR_IDLE;
    wire   fsm_wr_busreq = wr_fsm_r == WR_BUSREQ;
    wire   fsm_wr_addr   = wr_fsm_r == WR_ADDR;
    wire   fsm_wr_wd     = wr_fsm_r == WR_WD;
    wire   fsm_wr_lwd    = wr_fsm_r == = WR_LWD;
    wire    wr_last_data = wr_cnt_r == data_size - 1'd1;
    
    //Main  FSM
    wire rd_done;
    wire wr_done;
    reg we_r,re_r;
    reg  [1:0] main_fsm_r;
    
    always @(posedge hclk_i)
        if (~irst_n)
            main_fsm_r <= S0;
        else
            case(main_fsm_r)
                S0: if (we_r | re_r)
                main_fsm_r <= S1;
                S1: if (rd_done)
                main_fsm_r <= S2;
                S2: if (wr_done)
                main_fsm_r <= S0;
                default:
                main_fsm_r <= S0;
            endcase
    
    //Sub Read FSM
    always @(posedge hclk_i)
        if (~irst_n)
            rd_fsm_r <= RD_IDLE;
        else
            case(rd_fsm_r)
                RD_IDLE : if ((we_r | re_r) | (rd_done))
                rd_fsm_r <= RD_BUSREQ;
                RD_BUSREQ : if (hgrant_i & hready_i)
                rd_fsm_r <= RD_ADDR;
                RD_ADDR : if (hready_i)
                rd_fsm_r <= RD_RD;
                RD_RD : if (rd_cnt_r == data_size-2 & hready_i)
                rd_fsm_r <= RD_LRD;
                RD_LRD : if (hready_i & rd_last_data)
                rd_fsm_r <= RD_IDLE;
                default:
                rd_fsm_r <= RD_IDLE;
            endcase
    
    //Sub Write FSM
    always @(posedge hclk_i)
        if (~irst_n)
            wr_fsm_r <= WR_IDLE;
        else
            case(wr_fsm_r)
                WR_IDLE : if (rd_done)
                wr_fsm_r <= WR_BUSREQ;
                WR_BUSREQ : if (hgrant_i & hready_i)
                wr_fsm_r <= WR_ADDR;
                WR_ADDR : if (hready_i)
                wr_fsm_r <= WR_WD;
                WR_WD : if (wr_cnt_r == data_size-2 & hready_i)
                wr_fsm_r <= WR_LWD;
                WR_LWD : if (hready_i & wr_last_data)
                wr_fsm_r <= WR_IDLE;
                default:
                wr_fsm_r <= WR_IDLE;
            endcase
    //we_r
    always @(posedge hclk_i)
        if (~irst_n | we_r)
            we_r <= 1'b0;
            else(we_i)
            we_r <= 1'b1;
    
    //re_r
    always @(posedge hclk_i)
        if (~irst_n | re_r)
            re_r <= 1'b0;
            else(re_i)
            re_r <= 1'b1;
    
    assign rd_done = main_fsm_r == S1 & hready_i & rd_last_data;
    
    assign wr_done = main_fsm_r == S2 & hready_i & wr_last_data;
    
    assign hwrite_o = (main_fsm_r == S2) ? 'd1 : 'd0;
    
    assign  hbusreq_o = (fsm_rd_busreq || fsm_wr_busreq) ? 'd1 : 'd0;
    
    //rd_done_r
    always @(posedge hclk_i)
        if (~irst_n || rd_done_r)
            rd_done_r <= 'd0;
        else if (rd_done)
            rd_done_r <= 'd1;
    
    //wr_done_r
    always @(posedge hclk_i)
        if (~irst_n || wr_done_r)
            wr_done_r <= 'd0;
        else if (wr_done)
            wr_done_r <= 'd1;
    
    assign  htrans_o = (fsm_rd_addr || fsm_wr_addr) ? 2'b10 : 2'b11;
    wire  addr_add_en = (main_fsm_r == S1 || main_fsm_r == S2) &&
                        (fsm_rd_addr || fsm_rd_rd || fsm_wr_addr || fsm_wr_wd);
    
    //haddr_r
    always @(posedge hclk_i)
        if (~irst_n)
            haddr_r <= 32'd0;
        else if (main_fsm_r == S1 & fsm_rd_busreq & hready_i)
            haddr_r <= rd_base_addr;
        else if (main_fsm_r == S2 & fsm_wr_busreq & hready_i)
            haddr_r <= wr_base_addr;
        else if (addr_add_en)
            haddr_r <= haddr_r + 32'd4;
    
    
    //rd_cnt_r
    always @(posedge hclk_i)
        if (~irst_n)
            rd_cnt_r <= 3'd0;
        else if (hready_i & fsm_rd_addr)
            rd_cnt_r <= 3'd0;
        else if (hready_i & fsm_rd_rd)
            rd_cnt_r <= rd_cnt_r + 1'd1;
        else if (hready_i & rd_last_data)
            rd_cnt_r <= 3'd0;
    
    //wr_cnt_r
    always @(posedge hclk_i)
        if (~irst_n)
            wr_cnt_r <= 3'd0;
        else if (hready_i & fsm_wr_addr)
            wr_cnt_r <= 3'd0;
        else if (hready_i & fsm_wr_wd)
            wr_cnt_r <= wr_cnt_r + 1'd1;
        else if (hready_i & wr_last_data)
            wr_cnt_r <= 3'd0;
    
    reg  [31:0] rd_data_r [0 : data_size-1];

    always @(posedge hclk_i)
        if (~irst_n)
            {rd_data_r[0],rd_data_r[1],rd_data_r[2],rd_data_r[3]} <= 128'd0;
        else if (main_fsm_r == S1 & (fsm_rd_rd || fsm_rd_lrd) & hready_i)
            rd_data_r <= hrdata_i;
    
    assign  hwdata_o = (main_fsm_r == S2 & (fsm_wr_wd || fsm_wr_lwd) & hready_i) ? rd_data_r[wr_cnt_r] : 32'b0;
    assign  haddr_o  = haddr_r;
    
endmodule
