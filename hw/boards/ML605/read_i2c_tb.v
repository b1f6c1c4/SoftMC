module read_i2c_tb();
	
	reg clk = 0, reset = 0, start, next;
	wire [7:0] leds;
	wire scl, sda;
	
	parameter SADR = 7'b1010011;

	always #5 clk = ~clk;

	initial begin
		reset = 1; 
		next = 0;
		#20;
		reset = 0;
		#20;

		start = 1;
		wait(leds == 8'b11111111)
		#50;
		start = 0;
		#50;

		#1000
		next = 1;

		#1000
		next = 0;

		#1000
		next = 1;

		#1000
		next = 0;

		#1000
		next = 1;

		#1000
		next = 0;

		#1000
		next = 1;

	end

	read_i2c rdi2c(
    .clk 	(clk),
    .reset 	(reset),
    .start 	(start),
    .next 	(next),

    .leds 	(leds),

    .scl  	(scl),
    .sda 	(sda)
	);
	
	i2c_slave_model #(SADR) i2c_slave (
		.scl(scl),
		.sda(sda)
	);

	pullup p1(scl); // pullup scl line
	pullup p2(sda); // pullup sda line
endmodule