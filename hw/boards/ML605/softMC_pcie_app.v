`timescale 1ns / 1ps

module softMC_pcie_app #(
   parameter C_PCI_DATA_WIDTH = 9'd32, DQ_WIDTH = 64
)(
   input clk,
   input rst,
   output CHNL_RX_CLK,
   input CHNL_RX,
   output CHNL_RX_ACK,
   input CHNL_RX_LAST,
   input [31:0] CHNL_RX_LEN,
   input [30:0] CHNL_RX_OFF,
   input [C_PCI_DATA_WIDTH-1:0] CHNL_RX_DATA,
   input CHNL_RX_DATA_VALID,
   output CHNL_RX_DATA_REN,

   output CHNL_TX_CLK,
   output CHNL_TX,
   input CHNL_TX_ACK,
   output CHNL_TX_LAST,
   output [31:0] CHNL_TX_LEN,
   output [30:0] CHNL_TX_OFF,
   output [C_PCI_DATA_WIDTH-1:0] CHNL_TX_DATA,
   output CHNL_TX_DATA_VALID,
   input CHNL_TX_DATA_REN,

   output  app_en,
   input app_ack,
   output[31:0] app_instr,

   //Data read back Interface
   input rdback_fifo_empty,
   output rdback_fifo_rden,
   input[DQ_WIDTH*4 - 1:0] rdback_data
 );

   assign app_en = 0;
   assign app_instr = 0;
   assign rdback_fifo_rden = 0;

reg [C_PCI_DATA_WIDTH-1:0] rData={C_PCI_DATA_WIDTH{1'b0}};
reg [31:0] rLen=0;
reg [31:0] rCount=0;
reg [1:0] rState=0;

assign CHNL_RX_CLK = clk;
assign CHNL_RX_ACK = (rState == 2'd1);
assign CHNL_RX_DATA_REN = (rState == 2'd1);

assign CHNL_TX_CLK = clk;
assign CHNL_TX = (rState == 2'd3);
assign CHNL_TX_LAST = 1'd1;
assign CHNL_TX_LEN = rLen; // in words
assign CHNL_TX_OFF = 0;
assign CHNL_TX_DATA = rData;
assign CHNL_TX_DATA_VALID = (rState == 2'd3);

always @(posedge clk or posedge rst) begin
   if (rst) begin
      rLen <= 0;
      rCount <= 0;
      rState <= 0;
      rData <= 0;
   end
   else begin
      case (rState)

      2'd0: begin // Wait for start of RX, save length
         if (CHNL_RX) begin
            rLen <= CHNL_RX_LEN;
            rCount <= 0;
            rState <= 2'd1;
         end
      end

      2'd1: begin // Wait for last data in RX, save value
         if (CHNL_RX_DATA_VALID) begin
            rData <= CHNL_RX_DATA;
            rCount <= rCount + (C_PCI_DATA_WIDTH/32);
         end
         if (rCount >= rLen)
            rState <= 2'd2;
      end

      2'd2: begin // Prepare for TX
         rCount <= (C_PCI_DATA_WIDTH/32);
         rState <= 2'd3;
      end

      2'd3: begin // Start TX with save length and data value
         if (CHNL_TX_DATA_REN & CHNL_TX_DATA_VALID) begin
            rData <= {rCount[7:0] + 8'd4, rCount[7:0] + 8'd3, rCount[7:0] + 8'd2, rCount[7:0] + 8'd1};
            rCount <= rCount + (C_PCI_DATA_WIDTH/32);
            if (rCount >= rLen)
               rState <= 2'd0;
         end
      end

      endcase
   end
end

endmodule
