`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:11:31 10/14/2018 
// Design Name: 
// Module Name:    simple_counter 
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
`include "i2c_master_defines.v"

module i2c_read(
    input   clk,
    input   reset,
    input   start,
    input   next,
    
    output reg [7:0] leds,
    output  [1:0]   news_leds,

    output [255:0]  rdback_data_i2c,
    input           rdback_fifo_rden_i2c,
    output          rdback_fifo_empty_i2c,

    input           src_sel,
    
    inout   scl,
    inout   sda
    );
    
    reg [9:0] count;
    reg [2:0] cnt;
    reg state_cnt;
    
    wire next_botton, start_botton;
    
    reg state_nextbotton; 
    
    reg [7:0] read_out_addr;
    
    //assign news_leds = read_out_addr[3:0];
    
    reg [2:0] operation, operation_f;
    reg fun, fun_f;

    reg [7:0] read_out_data [255:0];


    reg [7:0] counter;
    wire reset_n = ~reset;

    reg [3:0] state, state_next;
    parameter IDLE              = 4'd0;
    parameter WAIT              = 4'd1;
    parameter SEND_INIT         = 4'd2;
    parameter SEND_START_WRITE  = 4'd3;
    parameter SEND_START_READ   = 4'd4;
    parameter SEND_WRITE        = 4'd5;
    parameter SEND_READ         = 4'd6;
    parameter SEND_STOP         = 4'd7;
    parameter FINISHED          = 4'd8;

    parameter SADR = 7'b1010011;
    parameter LASTONE = 8'd38;

    wire req_rdy;
    wire req_val = (state >= SEND_INIT && state <= SEND_STOP) ? 1'b1 : 1'b0;
    wire resp_val;
    wire resp_rdy = (state == WAIT) ? 1'b1 : 1'b0;
    wire req_go = req_val & req_rdy;
    wire resp_go = resp_val & resp_rdy;
    
    wire         wr_en  ;
    wire [255:0] din    ;
    
    wire [7:1] addr = SADR;
    wire [7:0] read_data;
	 reg [7:0] write_data;

    wire       full;
    wire       almost_full;
    
    
    debounce db_start
    (
    .clk    (clk),
    .reset  (reset),
    .key_i  (start),
    .key_o  (start_botton)
    );
    
    debounce db_next
    (
    .clk    (clk),
    .reset  (reset),
    .key_i  (next),
    .key_o  (next_botton)
    );
    
    // Check if the i2c buffer has ever been full 
    always @(posedge clk)
    begin
        if(reset)
        begin
            count <= 10'b0;
        end
        else if (count[3:0] == 4'b1111)
        begin
            count <= 4'b1111;
        end
        else if (full == 1'b1 || almost_full == 1'b1)
        begin
            count <= count + 1;
        end
    end
    

    //assign leds[7:4] = count[3:0];
    //assign leds[7]   = rdback_fifo_empty_i2c;
    //assign leds[6]   = full;
    //assign leds[5]   = start_botton;
    assign news_leds[0]   =  rdback_fifo_empty_i2c;
    assign news_leds[1]   = src_sel; // 0 for i2c read, 1 for normal read

    assign wr_en  =(((state == WAIT) && (operation_f == `OP_READ) && (resp_go == 1'b1)) || 
                    ((state == SEND_READ) && (req_go == 1'b1) && (counter != 8'b0)) )? 1'b1 : 1'b0;
    assign din    = {16'hf0f0, counter[7:0], read_data[7:0], 
                     16'hf1f1, counter[7:0], read_data[7:0],
                     16'hf2f2, counter[7:0], read_data[7:0],
                     16'hf3f3, counter[7:0], read_data[7:0],
                     16'hf4f4, counter[7:0], read_data[7:0],
                     16'hf5f5, counter[7:0], read_data[7:0],
                     16'hf6f6, counter[7:0], read_data[7:0],
                     16'hf7f7, counter[7:0], 8'hff
                     }; //256'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff; //{32{read_data}};
    
    always @(posedge clk)
    begin
        if (reset)
        begin
            read_out_addr <= 0;
            state_nextbotton <= 0;
        end
        else if (state_nextbotton == 0 && next_botton == 1'b1)
        begin
            read_out_addr <= (read_out_addr == LASTONE) ? 0 : (read_out_addr + 1);
            state_nextbotton <= 1'b1;
        end
        else if (state_nextbotton == 1'b1 && next_botton == 0)
        begin
            state_nextbotton <= 0;
        end
    end
    
    rdback_fifo spd_fifo(
        .clk    (clk),
        .srst   (reset),
        .din    (din),
        .wr_en  (wr_en),
        .rd_en  (rdback_fifo_rden_i2c),  
        .dout   (rdback_data_i2c),
        .full   (full),
        .almost_full    (almost_full),
        .empty  (rdback_fifo_empty_i2c)
    );

    /*always @(posedge clk)
    begin
        if (reset)
        begin
            news_leds[3:0] <= 0;
        end
        else //if (wr_en)
        begin
            news_leds[3:0] <= counter[3:0];//din[3:0];
        end
    
    end*/

    always @(*)
    begin
        if (state == IDLE)
        begin
            leds = read_out_data[read_out_addr];
        end
        /*else if (state == FINISHED)
        begin
            leds = 8'b11111111;
        end*/
        else begin
            leds = 8'b00000000;
            
            //leds[7:0] = {reset, rdback_fifo_empty_i2c, start_botton, next_botton, state};
        end
    end
    //assign leds = read_out_data[read_out_addr];
    



    always @(posedge clk)
    begin
        if (reset)
            state <= IDLE;
        else 
            state <= state_next;
    end

    always @(posedge clk)
    begin
        if (reset)
        begin
            read_out_data[0] <= 0;
        end
        else if (state == WAIT && resp_go && operation_f == `OP_READ)
        begin
            read_out_data[counter] <= read_data;
        end
    end

    
    always @(*) 
    begin
        case(state)
            IDLE:
            begin
                if (start_botton)
			    begin
				    state_next = SEND_INIT;	
                end
				else
                begin
                    state_next = IDLE;
				end
            end
            FINISHED:
            begin
                if (!start_botton)
                begin
                    state_next = IDLE;
                end
                else
                begin
                    state_next = FINISHED;
                end
            end
            WAIT:
            begin
                if (resp_go)
                begin
                    case({operation_f, fun_f})
                        {`OP_INITIALIZE, 1'b0}:
                            state_next = SEND_START_WRITE;
                        {`OP_START, 1'b1}:
                            state_next = SEND_WRITE;
                        {`OP_WRITE, 1'b0}:
                            state_next = SEND_START_READ;
                        {`OP_START, 1'b0}:
                            state_next = SEND_READ;
                        {`OP_READ, 1'b0}:
                            state_next = SEND_READ;
                        {`OP_READ, 1'b1}:
                            state_next = SEND_STOP;
                        {`OP_STOP, 1'b0}:
                            state_next = FINISHED;
                        default:
                            state_next = IDLE;
                    endcase
                end 
                else 
                begin
                    state_next = state;
                end
            end
            default:
            begin
                if (req_go)
                    state_next = WAIT;
                else 
                    state_next = state;
            end
        endcase
    end


    always @(posedge clk) 
    begin
        if (reset)
        begin
            counter <= 0;
        end
        else if (state == IDLE)
        begin
            counter <= 0;
        end
        else if (state == WAIT && operation_f == `OP_READ && resp_go)
        begin
            counter <= counter + 1;
        end
        else
        begin
            counter <= counter;
        end
    end

    always @(*)
    begin
        case (state)
            SEND_INIT:
            begin
                operation = `OP_INITIALIZE;
                fun = 0;
                write_data = 8'bxxxxxxxx;
            end
            SEND_WRITE:
            begin
                operation = `OP_WRITE;
                fun = 0;
                write_data = 8'b0;
            end
            SEND_READ:
            begin
                operation = `OP_READ;
                fun = (counter == LASTONE) ? 1'b1 : 1'b0;
                write_data = 8'bxxxxxxxx;
            end
            SEND_START_WRITE:
            begin
                operation = `OP_START;
                fun = 1'b1;
                write_data = 8'bxxxxxxxx;
            end
            SEND_START_READ:
            begin
                operation = `OP_START;
                fun = 1'b0;
                write_data = 8'bxxxxxxxx;
            end
            SEND_STOP:
            begin
                operation = `OP_STOP;
                fun = 0;
                write_data = 8'bxxxxxxxx;
            end
            default:
            begin
                operation = 3'bxxx;
                fun = 1'bx;
                write_data = 8'bxxxxxxxx;
            end
        endcase
    end

    always @(posedge clk)
    begin
        if (reset)
        begin
            operation_f <= 3'bxxx;
            fun_f <= 1'bx;
        end
        else if (state != WAIT)
        begin
            operation_f <= operation;
            fun_f <= fun;
        end
    end

    send_i2c_cmd sender(
    .clk 		(clk),
    .reset_n 		(reset_n),
    
    .addr		(addr),
    .write_data     	(write_data),
    .operation	 	(operation),
    .fun  		(fun),      // OP_START: 0 for read, 1 for write
    				    // OP_WRITE: 0 for normal, 1 for with stop
    				    // OP_READ:  0 for with ACK, 1 for with NACK
    .req_val  		(req_val),
    .req_rdy		(req_rdy),
    .read_data		(read_data),  
    .resp_val 		(resp_val),
    .resp_rdy  		(resp_rdy),

    .scl                (scl),
    .sda                (sda)
    );
endmodule
