`include "i2c_master_defines.v"

module send_i2c_cmd 
(
	input 			clk,
	input 			reset_n,

	input [7:1] 	addr,
	input [7:0] 	write_data,
	input [2:0] 	operation,
	input  			fun,    // OP_START: 0 for read, 1 for write
							// OP_WRITE: 0 for normal, 1 for with stop
							// OP_READ:  0 for with ACK, 1 for with NACK
	input  			req_val,
	output reg			req_rdy,
	output reg[7:0] 	read_data,  
	output reg			resp_val,
	input  			resp_rdy,

	inout 			scl,
	inout			sda
);

	//parameter SADR    = 7'b1010_011;

	parameter ERROR = 4'd0;
	parameter INIT = 4'd1;
	//parameter INIT_PRER_H = 2;
	//parameter INIT_CORE_EN = 3;
	parameter READY = 4'd2;
	parameter WR_TXR = 4'd3;
	parameter WR_CR = 4'd4;
	parameter SEND = 4'd5;
	parameter CHECK_FINISH = 4'd6;
	parameter CHECK_RESULT = 4'd7;
	//parameter SEND_WRITE;
	parameter WAIT_ACK = 4'd8;
	parameter RECOVER = 4'd9;
	parameter FINISHED = 4'd10;

	wire scl_o, scl_oen;
	wire sda_o, sda_oen;

	parameter PRER_LO = 4'b0000;
	parameter PRER_HI = 4'b0001;
	parameter CTR     = 4'b0010;
	parameter RXR     = 4'b1011;
	parameter TXR     = 4'b0011;
	parameter CR      = 4'b0100;
	parameter SR      = 4'b1100;


	// Signals that directly connected to the i2c module
	reg [2:0]	adr;
	reg [7:0]	dout;
	wire [7:0]	din;
	reg 		we;
	reg 		stb;
	reg 		cyc;
	wire 		ack;
	wire 		inta;


	reg [3:0] 	reg_addr;
	reg [7:0] 	reg_data;
	reg [2:0] 	operation_f;
	reg [7:0] 	device_addr;
	reg [7:0]	device_data; 
	reg 		fun_f;

	reg [3:0] state, state_next;
	
	wire req_go = req_rdy & req_val;
	wire resp_go = resp_val & resp_rdy;

	always @(posedge clk) 
	begin
		if (~reset_n) 
		begin
			state <= READY;
		end
		else begin
			state <= state_next;
		end
	end

	always @(*) 
	begin
		if (state == READY)
		begin
			req_rdy = 1'b1;
		end
		else begin
			req_rdy = 1'b0;
		end
	end

	always @(*) 
	begin
		if (state == FINISHED)
		begin
			resp_val = 1'b1;
		end
		else begin
			resp_val = 1'b0;
		end
	end

	always @(posedge clk)
	begin
		if (~reset_n)
		begin
			operation_f <= 0;
			device_addr <= 8'bx;
			device_data <= 8'bx;
			fun_f <= 1'bx;
		end
		else if (req_go) 
		begin
			operation_f <= operation;
			device_data <= write_data;
			fun_f <= fun;
			if (!fun)
			begin
				device_addr <= {addr[7:1], 1'b1};  // Read
			end
			else begin
				device_addr <= {addr[7:1], 1'b0};  // Write
			end
		end
	end

	always @(*)
	begin
		case (state)
			READY:
			begin
				if (req_go)
				begin
					case (operation)
						`OP_INITIALIZE:
						begin
							state_next = INIT;
						end
						`OP_START, `OP_WRITE:
						begin
							state_next = WR_TXR;
						end
						`OP_READ, `OP_STOP:
						begin
							state_next = WR_CR;
						end
						default:
						begin
							state_next = ERROR;
						end
					endcase
				end
				else
				begin
					state_next = READY;
				end
			end

			INIT, WR_TXR, WR_CR, CHECK_FINISH, CHECK_RESULT:
			begin
				state_next = SEND;
			end

			SEND:
			begin
				state_next = WAIT_ACK;			
			end

			WAIT_ACK:
			begin
				if (ack == 1'b0)
				begin
					state_next = WAIT_ACK;
				end
				else begin
					state_next = RECOVER;
				end
			end

			RECOVER:
			begin
				case (reg_addr)
					TXR:
					begin
						state_next = SEND; 
					end
					PRER_LO, PRER_HI:
					begin
						state_next = INIT; 
					end
					CR:
					begin
						state_next = CHECK_FINISH;
					end
					SR:
					begin
						if (din[1] == 1'b1)
						begin
							state_next = SEND;
						end
						else if (operation_f == `OP_READ)
						begin
							state_next = CHECK_RESULT; 
						end
						else begin
							state_next = FINISHED;
						end
					end
					RXR, CTR:
					begin
						state_next = FINISHED;
					end
					default:
					begin
						state_next = ERROR;
					end
				endcase
			end

			FINISHED:
			begin
				if (resp_go)
				begin
					state_next = READY;
				end
				else begin
					state_next = FINISHED;
				end
			end

			ERROR:
			begin
				state_next = ERROR;
			end

		endcase
	end

	always @(posedge clk)
	begin
		if (~reset_n)
		begin
			reg_addr <= 4'bxxxx;
			reg_data <= 8'bxxxxxxxx;
			read_data <= 8'bxxxxxxxx;
		end
		else if (state == WR_TXR)
		begin
			reg_addr <= TXR;
			case (operation_f)
				`OP_START:
				begin
					reg_data <= device_addr;
				end
				`OP_WRITE:
				begin
					reg_data <= device_data;
				end
				default:
				begin
					reg_data <= 8'bxxxxxxxx;
				end
			endcase
		end
		else if (state == WR_CR || (state == RECOVER && reg_addr == TXR))
		begin
			reg_addr <= CR;
			case (operation_f)
				`OP_START:
				begin
					reg_data <= 8'h90;
				end
				`OP_WRITE:
				begin
					reg_data <= (fun_f == 1'b1) ? 8'h50 : 8'h10; 
				end
				`OP_READ:
				begin
					reg_data <= (fun_f == 1'b1) ? 8'h28 : 8'h20;
				end
				`OP_STOP:
				begin
					reg_data <= 8'h40;
				end
				default:
				begin
					reg_data <= 8'bxxxxxxxx;
				end
			endcase
		end
		else if (state == CHECK_FINISH)
		begin
			reg_addr <= SR;
			reg_data <= 8'bxxxxxxxx;
		end
		else if (state == CHECK_RESULT)
		begin
			reg_addr <= RXR;
			reg_data <= 8'bxxxxxxxx;
		end
		else if (state == INIT && reg_addr == PRER_LO)
		begin
			reg_addr <= PRER_HI;
			reg_data <= 8'h00;     //controller runs at 66MHz, prescale = 131(d) = 0x83
		end
		else if (state == INIT && reg_addr == PRER_HI)
		begin
			reg_addr <= CTR;
			reg_data <= 8'h80;
		end
		else if (state == INIT)
		begin
			reg_addr <= PRER_LO;
			reg_data <= 8'h83;
		end
		else if (state == RECOVER && reg_addr == RXR)
		begin
			read_data <= din;
		end
	end

	// Whether it is a read reg or write reg, depends on the reg addr 
	always @(*)
	begin
		cyc  = 1'b0;
		stb  = 1'bx;
		adr  = 3'bx;
		dout = 8'bx;
		we   = 1'hx;
		//sel  = 1'bx;
		if (state == SEND || state == WAIT_ACK)
		begin
			cyc  = 1'b1;
			stb  = 1'b1;
			adr  = reg_addr[2:0];
			dout = (reg_addr == SR || reg_addr == RXR) ? 8'bx : reg_data;
			we   = (reg_addr == SR || reg_addr == RXR) ? 1'b0 : 1'b1;
			//sel  = 1'b1;
		end
	end

	i2c_master_top i2c_top (

		// wishbone interface
		.wb_clk_i(clk),
		.wb_rst_i(1'b0),
		.arst_i(reset_n),
		.wb_adr_i(adr),
		.wb_dat_i(dout),
		.wb_dat_o(din),
		.wb_we_i(we),
		.wb_stb_i(stb),
		.wb_cyc_i(cyc),
		.wb_ack_o(ack),
		.wb_inta_o(inta),   // dummy signal

		// i2c signals TODO
		.scl_pad_i(scl),
		.scl_pad_o(scl_o),
		.scl_padoen_o(scl_oen),
		.sda_pad_i(sda),
		.sda_pad_o(sda_o),
		.sda_padoen_o(sda_oen)
	);

	assign 	scl = scl_oen ? 1'bz : scl_o;
	assign 	sda = sda_oen ? 1'bz : sda_o;

	//i2c_slave_model #(SADR) i2c_slave (
	//	.scl(scl),
	//	.sda(sda)
	//);
        // create i2c lines
	/*delay m0_scl (scl0_oen ? 1'bz : scl0_o, scl),
	      m1_scl (scl1_oen ? 1'bz : scl1_o, scl),
	      m0_sda (sda0_oen ? 1'bz : sda0_o, sda),
	      m1_sda (sda1_oen ? 1'bz : sda1_o, sda);*/

	//pullup p1(scl); // pullup scl line
	//pullup p2(sda); // pullup sda line



endmodule
