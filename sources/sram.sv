module sram (
                data_out,
                addr,
                data_in,
                chip_select,
                write_enable,
                write_mask,
                clk,
                clk_inst,
                global_reset
                );

parameter ROWS = 1024, ADDR_WIDTH = 14, COLS = 8, WR_MASK_TYPE = 0, WR_MASK_WIDTH = 1, LATENCY = 2, MBIST_CHECKER_EN = 1;
//parameter ROWS = 128, ADDR_WIDTH = 7, COLS = 256, WR_MASK_TYPE = 1, WR_MASK_WIDTH = 256, LATENCY = 2, MBIST_CHECKER_EN = 1;

input  [ADDR_WIDTH-1:0]    addr;
input                      data_in;
input                      chip_select;
input                      write_enable;
input  [WR_MASK_WIDTH-1:0] write_mask;
input                      clk;
input                      clk_inst;
input                      global_reset;

output [COLS-1:0]          data_out;


reg    [COLS-1:0]          memory[ROWS-1:0];

wire   [COLS-1:0]          data_out;
wire   [COLS-1:0]          data_outi;
reg    [COLS-1:0]          data_tmp;

integer                    i;
integer                    j;

wire   [ADDR_WIDTH-1:0]    addr_dly;
wire   [COLS-1:0]          data_in_dly;
wire                       chip_select_dly;
reg    [COLS-1:0]          enables_expand;
wire   [COLS-1:0]          enables_dly;
wire                       write_dly;

wire                       forcex;


assign `POR_HLD_DELAY addr_dly       = addr;
assign `POR_HLD_DELAY data_in_dly    = data_in;
assign `POR_HLD_DELAY chip_select_dly = chip_select;
assign `POR_HLD_DELAY write_dly      = write_enable;

assign forcex = 1'b0;

always @(write_mask)
    case (WR_MASK_TYPE)
        0: enables_expand = {COLS{1'b1}};
        1: enables_expand = write_mask;
        8:
        begin
            enables_expand = {COLS{1'b0}};
            for (i=0; i<WR_MASK_WIDTH; i=i+1)
                enables_expand = enables_expand | ({8{write_mask[i]}} << (i << 3));
        end
        default:
        begin
            enables_expand = {COLS{1'b0}};
            for (i=0; i<; i=i+1)
            begin
                for (j=0; j<; j=j+1)
                    enables_expand = enables_expand | write_mask[i] << (i * WR_MASK_TYPE + j);
            end
        end
    endcase

assign `POR_HLD_DELAY enables_dly = enables_expand;


assign  data_outi = memory[addr_dly];

reg [COLS-1:0] data_out_int;

always @ (posedge clk_inst) begin
    if (chip_select_dly & write_dly)
        data_out_int <= `POR_MEM_DELAY data_outi;
    else
        data_out_int <= `POR_MEM_DELAY {COLS{1'bx}};
end


reg [3:0]      wren_dly;
reg [3:0]      rden_dly;
reg [COLS-1:0] data_out_dly[3:0];

reg                  chip_select_hold;
reg [ADDR_WIDTH-1:0] addr_hold;
reg [COLS-1:0]       data_in_hold;

wire               rden;
wire               wren;

assign rden = chip_select_dly & ~write_dly;
assign wren = chip_select_dly & write_dly;


always @ (posedge clk_inst or posedge global_reset)
    begin
        if (global_reset == 1'b1) begin
            wren_dly[0] <= 1'b0;
            wren_dly[1] <= 1'b0;
            wren_dly[2] <= 1'b0;
            wren_dly[3] <= 1'b0;

            rden_dly[0] <= 1'b0;
            rden_dly[1] <= 1'b0;
            rden_dly[2] <= 1'b0;
            rden_dly[3] <= 1'b0;
            chip_select_hold        <= 1'b0;
        end
        else begin
            wren_dly[0] <= wren;
            wren_dly[1] <= wren_dly[0];
            wren_dly[2] <= wren_dly[1];
            wren_dly[3] <= wren_dly[2];

            rden_dly[0] <= rden;
            rden_dly[1] <= rden_dly[0];
            rden_dly[2] <= rden_dly[1];
            rden_dly[3] <= rden_dly[2];
            chip_select_hold        <= chip_select;
        end
    end


always @ (posedge clk) begin
    if (chip_select_dly & write_dly & ~global_reset & ~forcex)
    begin
        data_tmp = memory[addr_dly];
        for (i=0; i<; i=i+1)
        begin
            if (enables_dly[i])
                data_tmp[i] = data_in_dly[i];
        end

        memory[addr_dly] = data_tmp;
    end
end


always @(forcex)
    if (forcex)
    begin
        for (i=0; i<; i=i+1)
        begin
            data_tmp[i] = 1'bx;
        end

        for (i=0; i<; i=i+1)
        begin
            memory[i] = data_tmp;
        end

    end

endmodule

