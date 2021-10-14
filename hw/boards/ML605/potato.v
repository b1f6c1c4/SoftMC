module potato (
    input clk,
    input rst,

    output i_rdy,
    input i_val,
    input [31:0] i_data,

    input o_rdy,
    output reg o_val,
    output reg [31:0] o_data

);

reg m_val;
wire en1;
wire en2;
wire m_rdy;

reg [31:0] m_data;
wire [31:0] o_data_ns;

assign i_rdy = m_rdy || !m_val;
assign en1 = i_rdy && i_val;

assign o_data_ns = m_data + 1;

assign m_rdy = o_rdy || !o_val;
assign en2 = m_rdy && m_val;


always @(posedge clk, posedge rst) begin
    if (rst) begin
        m_val <= 1'b0;
        m_data <= 32'b0;
    end else if (en1) begin
        m_val <= i_val;
        m_data <= i_data;
    end
end

always @(posedge clk, posedge rst) begin
    if (rst) begin
        o_val <= 1'b0;
        o_data <= 32'b0;
    end else if (en2) begin
        o_val <= m_val;
        o_data <= o_data_ns;
    end
end





    
endmodule
