module spi_master
#(
    parameter CLKS_PER_HALF_BIT = 2 // freq(spi_clk) = freq(i_clk) / 4
)
(
    input logic       i_rst,
    input logic       i_clk,

    // TX input to drive MOSI
    input logic       i_tx_valid,
    input logic [7:0] i_tx_byte,
    output logic      o_tx_ready,

    // RX output from MISO
    output logic       o_rx_valid,
    output logic [7:0] o_rx_byte,

    // SPI output
    output logic      o_sclk,
    output logic      o_mosi,
    output logic      o_cs_n,
    input logic       i_miso
);


typedef enum logic [0:0] {
    S_IDLE,     // wait for i_tx_valid to capture a byte
    S_TRANSMIT  // transmit out the byte
} tx_state_t;

parameter BITS_PER_BYTE = 8;

tx_state_t tx_state_nxt, tx_state_ff;

logic [7:0] tx_byte_ff, tx_byte_nxt, rx_byte_ff, rx_byte_nxt;

logic [3:0] spi_clks_cnt_nxt, spi_clks_cnt_ff; // always 8 clks per byte
logic [$bits(CLKS_PER_HALF_BIT)-1:0] clks_cnt_nxt,clks_cnt_ff;
logic sclk_ff, sclk_nxt;
logic cs_ff, cs_nxt;
logic rx_valid_ff, rx_valid_nxt;


always_comb begin

    tx_state_nxt = tx_state_ff;
    tx_byte_nxt  = tx_byte_ff;

    clks_cnt_nxt = clks_cnt_ff;
    spi_clks_cnt_nxt = spi_clks_cnt_ff;

    sclk_nxt = sclk_ff;
    cs_nxt  = cs_ff;

    rx_valid_nxt = rx_valid_ff;
    rx_byte_nxt  = rx_byte_ff;

    o_tx_ready = 1'b0;

    case (tx_state_ff)
        S_IDLE: begin
            o_tx_ready = 1'b1;
            sclk_nxt = 1'b0;
            rx_valid_nxt = 1'b0;
            if (i_tx_valid) begin
                tx_byte_nxt  = i_tx_byte;
                tx_state_nxt = S_TRANSMIT;
                spi_clks_cnt_nxt = BITS_PER_BYTE;
                clks_cnt_nxt = CLKS_PER_HALF_BIT;
                cs_nxt    = 1'b0;
                rx_byte_nxt = {rx_byte_ff[6:0], i_miso};
            end else begin
                tx_state_nxt = S_IDLE; // stay
                
            end
        end
        S_TRANSMIT: begin
            // o_tx_ready stays low since we are busy
            // done sending out all the SCLKS, can go back to idle
            if ((spi_clks_cnt_ff == 0) && (clks_cnt_ff == 1)) begin  
                tx_state_nxt = S_IDLE;  
                sclk_nxt   = 1'b0;      
                cs_nxt    = 1'b1; 
                rx_valid_nxt = 1'b1;           
            end else begin
                // start the next SPI_CLK cycle
                if ((clks_cnt_ff == 1)) begin 
                    if (sclk_ff) begin // shift MOSI out
                        spi_clks_cnt_nxt = spi_clks_cnt_ff - 1;
                        tx_byte_nxt      = tx_byte_ff << 1;
                    end else begin // shift MISO in
                        rx_byte_nxt = {rx_byte_ff[6:0], i_miso};
                    end
                    clks_cnt_nxt = CLKS_PER_HALF_BIT;
                    sclk_nxt = !sclk_nxt;
                end else begin
                    clks_cnt_nxt = clks_cnt_ff - 1;
                end
                tx_state_nxt = S_TRANSMIT;
            end
        end
    endcase
end

always_ff @(posedge i_clk) begin
    tx_state_ff         <= tx_state_nxt;
    tx_byte_ff          <= tx_byte_nxt;
    spi_clks_cnt_ff     <= spi_clks_cnt_nxt;
    clks_cnt_ff         <= clks_cnt_nxt;
    cs_ff               <= cs_nxt;
    rx_valid_ff         <= rx_valid_nxt;
    rx_byte_ff          <= rx_byte_nxt;

    sclk_ff             <= sclk_nxt;
    if (i_rst) begin
        tx_state_ff     <= S_IDLE;
        tx_byte_ff      <= '0;
        spi_clks_cnt_ff <= '0;
        clks_cnt_ff     <= '0;
        sclk_ff         <= 1'b0;
        cs_ff           <= 1'b1;
        rx_valid_ff     <= 1'b0;
        rx_byte_ff      <= 8'h00;
    end
end

// Drive outputs to slave
assign o_sclk     = sclk_ff;
assign o_mosi     = tx_byte_ff[7];
assign o_cs_n     = cs_ff; 

// Drive outputs to SW reg
assign o_rx_valid = rx_valid_ff;
assign o_rx_byte  = rx_byte_ff;

endmodule