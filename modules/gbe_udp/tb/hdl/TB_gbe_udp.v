`timescale 1ns/1ps

`define SIM_LENGTH 100000

`define APPCLK_PERIOD 4
`define MACCLK_PERIOD 8
`define CPUCLK_PERIOD 10
module TB_gbe_dup();

/**** Application Interface ****/
  wire        app_clk_i;

  wire  [7:0] app_tx_data;
  wire        app_tx_dvld;
  wire        app_tx_eof;
  wire [31:0] app_tx_destip;
  wire [15:0] app_tx_destport;

  wire        app_tx_afull;
  wire        app_tx_overflow;
  wire        app_tx_rst;

  wire  [7:0] app_rx_data;
  wire        app_rx_dvld;
  wire        app_rx_eof;
  wire [31:0] app_rx_srcip;
  wire [15:0] app_rx_srcport;
  wire        app_rx_badframe;

  wire        app_rx_overrun;
  wire        app_rx_afull;
  wire        app_rx_ack;
  wire        app_rx_rst;

/**** MAC Interface ****/

  wire        mac_tx_clk;
  wire        mac_tx_rst;
  wire  [7:0] mac_tx_data;
  wire        mac_tx_dvld;
  wire        mac_tx_ack;

  wire        mac_rx_clk;
  wire        mac_rx_rst;
  wire  [7:0] mac_rx_data;
  wire        mac_rx_dvld;
  wire        mac_rx_goodframe;
  wire        mac_rx_badframe;

/**** PHY Status/Control ****/
  wire [31:0] phy_status;
  wire [31:0] phy_control;

/**** CPU Bus Attachment ****/
  wire        wb_clk_i;
  wire        wb_rst_i;
  wire        wb_stb_i;
  wire        wb_cyc_i;
  wire        wb_we_i;
  wire [31:0] wb_adr_i;
  wire [31:0] wb_dat_i;
  wire  [3:0] wb_sel_i;
  wire [31:0] wb_dat_o;
  wire        wb_err_o;
  wire        wb_ack_o;

 gbe_udp #(
   .LOCAL_ENABLE     (1),
   .LOCAL_MAC        (48'h123456789abc),
   .LOCAL_IP         ({8'd100, 8'd101, 8'd102, 8'd103}),
   .LOCAL_PORT       (16'hdead),
   .LOCAL_GATEWAY    (8'h12),
   .PHY_CONFIG       (69),
   .DIS_CPU_TX       (0),
   .DIS_CPU_RX       (0),
   .TX_LARGE_PACKETS (0),
   .RX_DIST_RAM      (0),
   .ARP_CACHE_INIT   (0)
  ) gbe_udp_inst (
    .app_clk(app_clk_i),

    .app_tx_data(app_tx_data),
    .app_tx_dvld(app_tx_dvld),
    .app_tx_eof(app_tx_eof),
    .app_tx_destip(app_tx_destip),
    .app_tx_destport(app_tx_destport),

    .app_tx_afull(app_tx_afull),
    .app_tx_overflow(app_tx_overflow),
    .app_tx_rst(app_tx_rst),

    .app_rx_data(app_rx_data),
    .app_rx_dvld(app_rx_dvld),
    .app_rx_eof(app_rx_eof),
    .app_rx_srcip(app_rx_srcip),
    .app_rx_srcport(app_rx_srcport),
    .app_rx_badframe(app_rx_badframe),

    .app_rx_overrun(app_rx_overrun),
    .app_rx_afull(app_rx_afull),
    .app_rx_ack(app_rx_ack),
    .app_rx_rst(app_rx_rst),

    .mac_tx_clk(mac_tx_clk),
    .mac_tx_rst(mac_tx_rst),
    .mac_tx_data(mac_tx_data),
    .mac_tx_dvld(mac_tx_dvld),
    .mac_tx_ack(mac_tx_ack),

    .mac_rx_clk(mac_rx_clk),
    .mac_rx_rst(mac_rx_rst),
    .mac_rx_data(mac_rx_data),
    .mac_rx_dvld(mac_rx_dvld),
    .mac_rx_goodframe(mac_rx_goodframe),
    .mac_rx_badframe(mac_rx_badframe),

    .phy_status(phy_status),
    .phy_control(phy_control),

    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wb_stb_i(wb_stb_i),
    .wb_cyc_i(wb_cyc_i),
    .wb_we_i(wb_we_i),
    .wb_adr_i(wb_adr_i),
    .wb_dat_i(wb_dat_i),
    .wb_sel_i(wb_sel_i),
    .wb_dat_o(wb_dat_o),
    .wb_err_o(wb_err_o),
    .wb_ack_o(wb_ack_o)
  );


  reg [31:0] clk_counter;
  reg rst;

  initial begin
    $dumpvars;
    clk_counter <= 32'b0;
    rst <= 1'b1;
    #100
    rst <= 1'b0;
    #`SIM_LENGTH
    $display("FAILED: simulation timed out");
    $finish;
  end

  always
   #1 clk_counter <= clk_counter + 1;

  wire app_clk = (clk_counter % (`APPCLK_PERIOD)) < ((`APPCLK_PERIOD)/2);
  wire mac_clk = (clk_counter % (`MACCLK_PERIOD)) < ((`MACCLK_PERIOD)/2);
  wire cpu_clk = (clk_counter % (`CPUCLK_PERIOD)) < ((`CPUCLK_PERIOD)/2);

  /**** APP TX ****/
  assign app_clk_i = app_clk;

  reg app_rst;
  always @(posedge app_clk) begin
    app_rst <= rst;
  end

  reg [16:0] app_tx_counter;
  reg        app_tx_en;

  always @(posedge app_clk) begin
    if (app_rst) begin
      app_tx_counter <= 16'h0;
      app_tx_en <= 1'b0;
    end else begin
      if (app_tx_afull)
        app_tx_en <= 1'b0;
      if (!app_tx_afull)
        app_tx_en <= 1'b1;

      if (app_tx_en)
        app_tx_counter <= app_tx_counter + 1;
    end
  end

  assign app_tx_data     = !app_tx_counter[0] ? app_tx_counter[16:9] : app_tx_counter[8:1];
  assign app_tx_dvld     = 1'b0;//app_tx_en && !app_rst;
  assign app_tx_eof      = app_tx_counter[7:0] == {8{1'b1}};
  assign app_tx_destip   = {8'd192, 8'd168, 8'd64, 8'd1};
  assign app_tx_destport = 16'hbeef;

  always @(posedge app_clk) begin
    if (app_tx_overflow) begin
      $display("FAILED: unexpected tx buffer overflow");
      $finish;
    end
  end

  assign app_tx_rst = app_rst;
 

  /**** MAC TX ****/

  assign mac_tx_clk = mac_clk;
  reg mac_rst;
  always @(posedge mac_clk) begin
    mac_rst <= rst;
  end
  assign mac_tx_rst = mac_rst;

  reg [1:0] mac_tx_state;
  reg [3:0] wait_counter;

  always @(posedge mac_clk) begin
    if (mac_rst) begin
      mac_tx_state <= 1'b0;
    end else begin
      case (mac_tx_state)
        0: begin
          if (mac_tx_dvld)
            mac_tx_state <= 1;
        end
        1: begin
          mac_tx_state <= 2;
        end
        2: begin
          wait_counter <= 15;
          if (!mac_tx_dvld)
            mac_tx_state <= 3;
        end
        3: begin
          if (wait_counter == 0) begin
            mac_tx_state <= 0;
          end
          wait_counter <= wait_counter - 1;
        end
      endcase
    end
  end

  assign mac_tx_ack = mac_tx_state == 1;

  reg [31:0] foo_index;

  always @(posedge mac_clk) begin
    if (mac_rst) begin
      foo_index <= 0;
    end else begin
      if (mac_tx_state == 1 || mac_tx_state == 2) begin
        foo_index <= foo_index + 1;
        if (mac_tx_dvld)
          $display("mac_tx: %4d - %x", foo_index, mac_tx_data);
      end
      if (mac_tx_state == 3) begin
        foo_index <= 0;
      end
    end
  end


  /**** CPU Master ****/

  reg cpu_rst;
  always @(posedge cpu_clk) begin
    cpu_rst <= rst;
  end

  assign wb_clk_i = cpu_clk;
  assign wb_rst_i = cpu_rst;

  reg [31:0] cpu_tx_progress;
  reg [2:0] cpu_state;
  reg [31:0] cpu_test_count;
  localparam CPU_WR   = 0;
  localparam CPU_SEND = 1;

  reg wait_ack;

  reg cpu_stb;
  reg [31:0] wb_adr_reg;
  reg        wb_we_reg;
  reg [31:0] wb_dat_reg;

  assign wb_stb_i = cpu_stb;
  assign wb_cyc_i = cpu_stb;
  assign wb_we_i  = wb_we_reg;
  assign wb_adr_i = wb_adr_reg;
  assign wb_dat_i = wb_dat_reg;
  assign wb_sel_i = 4'b1111;

  localparam CPU_TXSIZE = 16'd77;

  always @(posedge cpu_clk) begin
    cpu_stb <= 1'b0;

    if (cpu_rst) begin
      cpu_state <= CPU_WR;
      cpu_tx_progress <= 0;
      cpu_test_count  <= 0;
      wait_ack <= 1'b0;
    end else begin
      if (wait_ack) begin
        if (wb_ack_o || wb_err_o)
          wait_ack <= 1'b0;
      end else begin
        cpu_stb <= 1'b1;
        case (cpu_state)
          CPU_WR: begin
            wait_ack   <= 1'b1;
            wb_we_reg  <= 1'b1;
            wb_adr_reg <= 32'h1000 + (cpu_tx_progress[7:0] << 2);
            wb_dat_reg <= cpu_tx_progress[31:0];
            cpu_tx_progress <= cpu_tx_progress + 1;
            if (cpu_tx_progress[7:0] == 63)
              cpu_state <= CPU_SEND;
          end
          CPU_SEND: begin
            wait_ack   <= 1'b1;
            wb_we_reg  <= 1'b1;
            wb_adr_reg <= 6*4;
            wb_dat_reg <= {CPU_TXSIZE, 16'hffff};
            if (cpu_test_count == 5) begin
              cpu_state <= 2;
            end else begin
              cpu_state <= CPU_WR;
            end
            cpu_test_count <= cpu_test_count + 1;
          end
        endcase
      end
    end
  end



endmodule
