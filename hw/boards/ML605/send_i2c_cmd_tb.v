`include "i2c_master_defines.v"
 
module send_i2c_cmd_tb ();

    reg clk = 0;
    reg reset_n;
    reg [7:1] addr;
    reg [7:0] write_data;
    reg [2:0] operation;
    reg fun;
    reg req_val;
    reg resp_rdy;
    
    wire resp_val;
    wire req_rdy;
    wire [7:0] read_data;

    parameter SADR    = 7'b0010_000;
    
	 always #5 clk = ~clk;

    initial begin
        reset_n = 1'b0;
        req_val = 1'b0;
        write_data = 8'b0;
        addr = SADR;
        resp_rdy = 1'b0;

        #20 
        reset_n = 1'b1;
        #10
        operation = `OP_INITIALIZE;
        req_val = 1'b1;
        resp_rdy = 1'b1;
         
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20


        operation = `OP_START;
        fun = 1'b1;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20


        operation = `OP_WRITE;
        fun = 1'b0;
        write_data = 8'h01;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20
        
		  
		  operation = `OP_WRITE;
        fun = 1'b0;
        write_data = 8'h01;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20

        operation = `OP_WRITE;
        fun = 1'b1;   // with stop
        write_data = 8'hc3;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #200;
		  
		  // start to read
		  operation = `OP_START;
        fun = 1'b1;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20


        operation = `OP_WRITE;
        fun = 1'b0;
        write_data = 8'h01;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20

		  operation = `OP_START;
        fun = 1'b0;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20

		  operation = `OP_READ;
        fun = 1'b0;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #20
		  
		  operation = `OP_READ;
        fun = 1'b1;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #200;

			
		  operation = `OP_STOP;
        fun = 1'b0;
        req_val = 1'b1;
        resp_rdy = 1'b1;
        
        wait (resp_val);
        #10

        resp_rdy = 1'b0;
        req_val = 1'b0;
        #200;

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
    .resp_rdy  		(resp_rdy)
    );


     



endmodule
