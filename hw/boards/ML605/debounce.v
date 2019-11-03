`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:45:43 10/09/2018 
// Design Name: 
// Module Name:    debounce 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module debounce(
    input clk,
	input reset,
    input key_i,
    output key_o
);

    parameter NUMBER = 24'd1_000_000;  //delay 0.1s
    parameter NBITS = 24;

    reg [NBITS-1:0] count;
    reg key_o_temp;

    reg key_m;
    reg key_i_t1,key_i_t2;

    assign key_o = key_o_temp;

    always @ (posedge clk) begin
	key_i_t1 <= key_i;
	key_i_t2 <= key_i_t1;
    end

    always @ (posedge clk) begin
		if (reset) begin
			key_m <= 0;
			count <= 0;
            key_o_temp <= 0;
		end
        else if (key_m!=key_i_t2) begin
            key_m <= key_i_t2;
            count <= 0;
            key_o_temp <= key_o_temp;
        end
        else if (count == NUMBER) begin
            key_o_temp <= key_m;
            count <= NUMBER;
            key_m <= key_m;
        end
        else begin
            count <= count+1;
            key_o_temp <= key_o_temp;
            key_m <= key_m;
        end
    end
endmodule

