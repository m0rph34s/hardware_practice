module tb_spi_master ();

    parameter CLK_PERIOD = 10; // 100MHz
    parameter CLKS_PER_HALF_BIT = 2; // freq(spi_clk) = freq(i_clk) / 4 = 25MHz

    
    logic       rst;
    logic       clk;
    
    // TX input to drive MOSI
    logic       tx_valid;
    logic [7:0] tx_byte;
    logic      tx_ready;

    // RX output from MISO
    logic       rx_valid;
    logic [7:0] rx_byte;
    
    // SPI output
    logic      sclk;
    logic      mosi;
    logic      miso;
    logic      cs_n;

    assign miso = mosi;

    spi_master
    #(
        .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT) // freq(spi_clk) = freq(i_clk) / 4
    ) u_spi_master
    (
        .i_rst(rst),
        .i_clk(clk),
    
        // TX input to drive MOSI
        .i_tx_valid(tx_valid),
        .i_tx_byte(tx_byte),
        .o_tx_ready(tx_ready),
    
        // RX output from MISO
        .o_rx_valid(rx_valid),
        .o_rx_byte(rx_byte),
    
        // SPI output
        .o_sclk(sclk),
        .o_mosi(mosi),
        .o_cs_n(cs_n),
        .i_miso(miso)
    );

    task send_byte(input logic [7:0] data);
        @(posedge clk);
        tx_byte <= data;
        tx_valid <=1'b1;
        @(posedge clk);
        tx_valid <=1'b0;
        @(posedge tx_ready);
    endtask

    initial begin
        // Required for EDA Playground
        $dumpfile("dump.vcd"); 
        $dumpvars;

        clk = 1'b0;
        rst = 1'b1;
        tx_valid = 1'b0;
        #50;
        rst = 1'b0;
        #1000;
        send_byte(8'h3E);
        #300;
        $finish();        

    end

    always #CLK_PERIOD clk = !clk;



endmodule