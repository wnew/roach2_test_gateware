`include "build_parameters.v"
`include "parameters.v"
`include "mem_layout.v"

module toplevel(
    input          sys_clk_n,
    input          sys_clk_p,

    /* TODO: add tests for aux signals */
    input          aux_clk_n,
    input          aux_clk_p,
    input          aux_synci_n,
    input          aux_synci_p,
    output         aux_synco_n,
    output         aux_synco_p,

`ifdef REV0
    inout   [11:0] v6_gpio,
`else
    inout   [15:0] v6_gpio,
`endif

    input          ppc_perclk,
    input   [5:29] ppc_paddr,
    /* TODO: add test for ppc_pcsn[1] */
    input    [1:0] ppc_pcsn,
    inout   [0:31] ppc_pdata,
    input    [0:3] ppc_pben,
    input          ppc_poen,
    input          ppc_pwrn,
    input          ppc_pblastn,
    output         ppc_prdy,
    output         ppc_doen,

    /* TODO: add test for v6_irqn */
    output         v6_irqn,

    input kat_adc0_clk_n,
    input kat_adc0_clk_p,
    input kat_adc0_sync_n,
    input kat_adc0_sync_p,
    input kat_adc0_overrange_n,
    input kat_adc0_overrange_p,
    input [7:0] kat_adc0_di_d_n,
    input [7:0] kat_adc0_di_d_p,
    input [7:0] kat_adc0_di_n,
    input [7:0] kat_adc0_di_p,
    input [7:0] kat_adc0_dq_d_n,
    input [7:0] kat_adc0_dq_d_p,
    input [7:0] kat_adc0_dq_n,
    input [7:0] kat_adc0_dq_p,
    output kat_adc0_spi_clk,
    output kat_adc0_spi_data,
    output kat_adc0_spi_cs,
    inout kat_adc0_iic_sda,
    inout kat_adc0_iic_scl,
  

    inout   [11:0] mgt_gpio,

    output  [31:0] mgt_tx_n,
    output  [31:0] mgt_tx_p,
    input   [31:0] mgt_rx_n,
    input   [31:0] mgt_rx_p,

    /*
    input    [7:0] ext_refclk_p,
    input    [7:0] ext_refclk_n,
    */
    /* TODO: add test for mezzanine clock inputs */

    input    [2:0] xaui_refclk_n,
    input    [2:0] xaui_refclk_p
  );
  
  wire clk_200;
  wire clk_125;
  wire clk_100;

  wire rst_200;
  wire rst_125;
  wire rst_100;

  wire idelay_rdy;

  infrastructure infrastructure_inst (
    .sys_clk_buf_n  (sys_clk_n),
    .sys_clk_buf_p  (sys_clk_p),
    .sys_clk0       (clk_100),
    .sys_clk180     (),
    .sys_clk270     (),
    .clk_200        (clk_200),
    .sys_rst        (rst_100),
    .idelay_rdy     (idelay_rdy)
  );

  reg rst_200R;
  reg rst_200RR;

  always @(posedge clk_200) begin
    rst_200R  <= rst_100;
    rst_200RR <= rst_200R;
  end
  assign rst_200 = rst_200RR;


  wire [2:0] knight_rider_speed;

  knight_rider knight_rider_inst(
    .clk  (clk_100),
    .rst  (rst_100),
    .led  (v6_gpio[7:0]),
    .rate (knight_rider_speed)
  );

  wire aux_clk;
  IBUFGDS #(
    .IOSTANDARD("LVDS_25"),
    .DIFF_TERM("TRUE")
  ) ibufgds_aux_clk (
    .I (aux_clk_p),
    .IB(aux_clk_n),
    .O (aux_clk)
  );
  
  wire aux_synci;
  IBUFDS #(
    .IOSTANDARD("LVDS_25"),
    .DIFF_TERM("TRUE")
  ) ibufds_aux_synci (
    .I (aux_synci_p),
    .IB(aux_synci_n),
    .O (aux_synci)
  );
  
  wire aux_synco;
  OBUFDS #(
    .IOSTANDARD("LVDS_25")
  ) obufds_aux_synco (
    .O (aux_synco_p),
    .OB(aux_synco_n),
    .I (aux_synco)
  );

  reg [9:0] sync_counter;

  always @(posedge clk_100) begin
    sync_counter <= sync_counter + 10'd1;
  end

  assign aux_synco = sync_counter == 10'b0;

  wire        wb_clk_i;
  wire        wb_rst_i;
  wire        wbm_cyc_o;
  wire        wbm_stb_o;
  wire        wbm_we_o;
  wire  [3:0] wbm_sel_o;
  wire [31:0] wbm_adr_o;
  wire [31:0] wbm_dat_o;
  wire [31:0] wbm_dat_i;
  wire        wbm_ack_i;
  wire        wbm_err_i;

  wire [0:31] epb_data_i;
  wire [0:31] epb_data_o;
  wire        epb_data_oe_n;
  wire        epb_clk;

  epb_infrastructure epb_infrastructure_inst(
    .epb_data_buf  (ppc_pdata),
    .epb_data_oe_n (epb_data_oe_n),
    .epb_data_in   (epb_data_o),
    .epb_data_out  (epb_data_i),
    .per_clk       (ppc_perclk),
    .epb_clk       (epb_clk)
  );

  OBUF #(
    .IOSTANDARD("LVCMOS25")
  ) OBUF_v6_irqn (
    .O (v6_irqn),
    .I (1'b0)
  );

  wire ppc_prdy_int;

  reg epb_rstR;
  reg epb_rstRR;

  always @(posedge epb_clk) begin
    epb_rstR  <= rst_100;
    epb_rstRR <= epb_rstR;
  end

  assign wb_clk_i = epb_clk;
  assign wb_rst_i = epb_rstRR;

  epb_wb_bridge_reg epb_wb_bridge_reg_inst(
    .wb_clk_i (wb_clk_i),
    .wb_rst_i (wb_rst_i),
    .wb_cyc_o (wbm_cyc_o),
    .wb_stb_o (wbm_stb_o),
    .wb_we_o  (wbm_we_o),
    .wb_sel_o (wbm_sel_o),
    .wb_adr_o (wbm_adr_o),
    .wb_dat_o (wbm_dat_o),
    .wb_dat_i (wbm_dat_i),
    .wb_ack_i (wbm_ack_i),
    .wb_err_i (wbm_err_i),

    .epb_clk       (epb_clk),
    .epb_cs_n      (ppc_pcsn[0]),
    .epb_oe_n      (ppc_poen),
    .epb_r_w_n     (ppc_pwrn),
    .epb_be_n      (ppc_pben), 
    .epb_addr      (ppc_paddr),
    .epb_data_i    (epb_data_i),
    .epb_data_o    (epb_data_o),
    .epb_data_oe_n (epb_data_oe_n),
    .epb_rdy       (ppc_prdy_int),
    .epb_doen      (ppc_doen)
  );
  assign ppc_prdy = !ppc_pcsn[0] ? ppc_prdy_int : 1'b1;

  localparam NUM_SLAVES    = 24;

  localparam DRAM_SLI      = 23;
  localparam QDR3_SLI      = 22;
  localparam QDR2_SLI      = 21;
  localparam QDR1_SLI      = 20;
  localparam QDR0_SLI      = 19;
  localparam APP_SLI       = 18;
  localparam GBE_SLI       = 17;
  localparam TGE7_SLI      = 16;
  localparam TGE6_SLI      = 15;
  localparam TGE5_SLI      = 14;
  localparam TGE4_SLI      = 13;
  localparam TGE3_SLI      = 12;
  localparam TGE2_SLI      = 11;
  localparam TGE1_SLI      = 10;
  localparam TGE0_SLI      =  9;
  localparam ZDOK1_SLI     =  8;
  localparam ZDOK0_SLI     =  7;
  localparam DRAMCONF_SLI  =  6;
  localparam QDR3CONF_SLI  =  5;
  localparam QDR2CONF_SLI  =  4;
  localparam QDR1CONF_SLI  =  3;
  localparam QDR0CONF_SLI  =  2;
  localparam GPIO_SLI      =  1;
  localparam SYSBLOCK_SLI  =  0;

  localparam SLAVE_BASE = {
    `DRAM_A_BASE,
    `QDR3_A_BASE,
    `QDR2_A_BASE,
    `QDR1_A_BASE,
    `QDR0_A_BASE,
    `APP_A_BASE,
    `GBE_A_BASE,
    `TGE7_A_BASE,
    `TGE6_A_BASE,
    `TGE5_A_BASE,
    `TGE4_A_BASE,
    `TGE3_A_BASE,
    `TGE2_A_BASE,
    `TGE1_A_BASE,
    `TGE0_A_BASE,
    `ZDOK1_A_BASE,
    `ZDOK0_A_BASE,
    `DRAMCONF_A_BASE,
    `QDR3CONF_A_BASE,
    `QDR2CONF_A_BASE,
    `QDR1CONF_A_BASE,
    `QDR0CONF_A_BASE,
    `GPIO_A_BASE,
    `SYSBLOCK_A_BASE
  };

  localparam SLAVE_HIGH = {
    `DRAM_A_HIGH,
    `QDR3_A_HIGH,
    `QDR2_A_HIGH,
    `QDR1_A_HIGH,
    `QDR0_A_HIGH,
    `APP_A_HIGH,
    `GBE_A_HIGH,
    `TGE7_A_HIGH,
    `TGE6_A_HIGH,
    `TGE5_A_HIGH,
    `TGE4_A_HIGH,
    `TGE3_A_HIGH,
    `TGE2_A_HIGH,
    `TGE1_A_HIGH,
    `TGE0_A_HIGH,
    `ZDOK1_A_HIGH,
    `ZDOK0_A_HIGH,
    `DRAMCONF_A_HIGH,
    `QDR3CONF_A_HIGH,
    `QDR2CONF_A_HIGH,
    `QDR1CONF_A_HIGH,
    `QDR0CONF_A_HIGH,
    `GPIO_A_HIGH,
    `SYSBLOCK_A_HIGH
  };

  wire    [NUM_SLAVES - 1:0] wbs_cyc_o;
  wire    [NUM_SLAVES - 1:0] wbs_stb_o;
  wire                       wbs_we_o;
  wire                 [3:0] wbs_sel_o;
  wire                [31:0] wbs_adr_o;
  wire                [31:0] wbs_dat_o;
  wire [32*NUM_SLAVES - 1:0] wbs_dat_i;
  wire    [NUM_SLAVES - 1:0] wbs_ack_i;
  wire    [NUM_SLAVES - 1:0] wbs_err_i;

  wbs_arbiter #(
    .NUM_SLAVES (NUM_SLAVES),
    .SLAVE_ADDR (SLAVE_BASE),
    .SLAVE_HIGH (SLAVE_HIGH),
    .TIMEOUT    (1024)
  ) wbs_arbiter_inst (
    .wb_clk_i  (wb_clk_i),
    .wb_rst_i  (wb_rst_i),

    .wbm_cyc_i (wbm_cyc_o),
    .wbm_stb_i (wbm_stb_o),
    .wbm_we_i  (wbm_we_o),
    .wbm_sel_i (wbm_sel_o),
    .wbm_adr_i (wbm_adr_o),
    .wbm_dat_i (wbm_dat_o),
    .wbm_dat_o (wbm_dat_i),
    .wbm_ack_o (wbm_ack_i),
    .wbm_err_o (wbm_err_i),

    .wbs_cyc_o (wbs_cyc_o),
    .wbs_stb_o (wbs_stb_o),
    .wbs_we_o  (wbs_we_o),
    .wbs_sel_o (wbs_sel_o),
    .wbs_adr_o (wbs_adr_o),
    .wbs_dat_o (wbs_dat_o),
    .wbs_dat_i (wbs_dat_i),
    .wbs_ack_i (wbs_ack_i)
  );

  wire        debug_clk;
  wire [31:0] debug_regin_0;
  wire [31:0] debug_regin_1;
  wire [31:0] debug_regin_2;
  wire [31:0] debug_regin_3;
  wire [31:0] debug_regin_4;
  wire [31:0] debug_regin_5;
  wire [31:0] debug_regin_6;
  wire [31:0] debug_regin_7;
  wire [31:0] debug_regout_0;
  wire [31:0] debug_regout_1;
  wire [31:0] debug_regout_2;
  wire [31:0] debug_regout_3;
  wire [31:0] debug_regout_4;
  wire [31:0] debug_regout_5;
  wire [31:0] debug_regout_6;
  wire [31:0] debug_regout_7;

  sys_block #(
    .BOARD_ID (`BOARD_ID),
    .REV_MAJ  (`REV_MAJOR),
    .REV_MIN  (`REV_MINOR),
    .REV_RCS  (`RCS_UPTODATE ? `REV_RCS : 32'b0)
  ) sys_block_inst (
    .wb_clk_i (wb_clk_i),
    .wb_rst_i (wb_rst_i),
    .wb_cyc_i (wbs_cyc_o[SYSBLOCK_SLI]),
    .wb_stb_i (wbs_stb_o[SYSBLOCK_SLI]),
    .wb_we_i  (wbs_we_o),
    .wb_sel_i (wbs_sel_o),
    .wb_adr_i (wbs_adr_o),
    .wb_dat_i (wbs_dat_o),
    .wb_dat_o (wbs_dat_i[(SYSBLOCK_SLI+1)*32-1:(SYSBLOCK_SLI)*32]),
    .wb_ack_o (wbs_ack_i[SYSBLOCK_SLI]),
    .wb_err_o (wbs_err_i[SYSBLOCK_SLI]),

    .debug_clk (debug_clk),
    .regin_0   (debug_regin_0),
    .regin_1   (debug_regin_1),
    .regin_2   (debug_regin_2),
    .regin_3   (debug_regin_3),
    .regin_4   (debug_regin_4),
    .regin_5   (debug_regin_5),
    .regin_6   (debug_regin_6),
    .regin_7   (debug_regin_7),
    .regout_0  (debug_regout_0),
    .regout_1  (debug_regout_1),
    .regout_2  (debug_regout_2),
    .regout_3  (debug_regout_3),
    .regout_4  (debug_regout_4),
    .regout_5  (debug_regout_5),
    .regout_6  (debug_regout_6),
    .regout_7  (debug_regout_7)
  );

  assign debug_clk = clk_200;

  /************************ ZDOK 0 ****************************/

  wire [79:0] zdok0_out;
  wire [79:0] zdok0_in;
  wire [79:0] zdok0_oe;
  wire [79:0] zdok0_ded;

  gpio_controller #(
    .COUNT(80)
  ) gpio_zdok0 (
    .wb_clk_i (wb_clk_i),
    .wb_rst_i (wb_rst_i),
    .wb_cyc_i (wbs_cyc_o[ZDOK0_SLI]),
    .wb_stb_i (wbs_stb_o[ZDOK0_SLI]),
    .wb_we_i  (wbs_we_o),
    .wb_sel_i (wbs_sel_o),
    .wb_adr_i (wbs_adr_o),
    .wb_dat_i (wbs_dat_o),
    .wb_dat_o (wbs_dat_i[(ZDOK0_SLI+1)*32-1:(ZDOK0_SLI)*32]),
    .wb_ack_o (wbs_ack_i[ZDOK0_SLI]),
    .wb_err_o (wbs_err_i[ZDOK0_SLI]),

    .gpio_out (zdok0_out),
    .gpio_in  (zdok0_in),
    .gpio_oe  (zdok0_oe),
    .gpio_ded (zdok0_ded)
  );


  gpio_controller #(
    .COUNT(80)
  ) gpio_zdok1 (
    .wb_clk_i (wb_clk_i),
    .wb_rst_i (wb_rst_i),
    .wb_cyc_i (wbs_cyc_o[ZDOK1_SLI]),
    .wb_stb_i (wbs_stb_o[ZDOK1_SLI]),
    .wb_we_i  (wbs_we_o),
    .wb_sel_i (wbs_sel_o),
    .wb_adr_i (wbs_adr_o),
    .wb_dat_i (wbs_dat_o),
    .wb_dat_o (wbs_dat_i[(ZDOK1_SLI+1)*32-1:(ZDOK1_SLI)*32]),
    .wb_ack_o (wbs_ack_i[ZDOK1_SLI]),
    .wb_err_o (wbs_err_i[ZDOK1_SLI]),

    .gpio_out (zdok1_out),
    .gpio_in  (zdok1_in),
    .gpio_oe  (zdok1_oe),
    .gpio_ded (zdok1_ded)
  );

  
  kat_adc_interface
  #(
     .EXTRA_REG (1)
  ) kac_adc_interface_inst (
     .adc_clk_p         (kat_adc0_clk_p),
     .adc_clk_n         (kat_adc0_clk_n),
     .adc_sync_p        (kat_adc0_sync_p),
     .adc_sync_n        (kat_adc0_sync_n),
     .adc_overrange_p   (kat_adc0_overrange_p),
     .adc_overrange_n   (kat_adc0_overrange_n),
     .adc_rst           (kat_adc0_adc_rst),
     .adc_powerdown     (kat_adc0_adc_powerdown),
     .adc_di_d_p        (kat_adc0_di_d_p),
     .adc_di_d_n        (kat_adc0_di_d_n),
     .adc_di_p          (kat_adc0_di_p),
     .adc_di_n          (kat_adc0_di_n),
     .adc_dq_d_p        (kat_adc0_dq_d_p),
     .adc_dq_d_n        (kat_adc0_dq_d_n),
     .adc_dq_p          (kat_adc0_dq_p),
     .adc_dq_n          (kat_adc0_dq_n),
  
     .user_datai3       (kat_adc0_user_datai3),
     .user_datai2       (kat_adc0_user_datai2),
     .user_datai1       (kat_adc0_user_datai1),
     .user_datai0       (user_datai0),
     .user_dataq3       (kat_adc0_user_dataq3),
     .user_dataq2       (kat_adc0_user_dataq2),
     .user_dataq1       (kat_adc0_user_dataq1),
     .user_dataq0       (kat_adc0_user_dataq0),
     .user_sync0        (kat_adc0_user_sync0),
     .user_sync1        (kat_adc0_user_sync1),
     .user_sync2        (kat_adc0_user_sync2),
     .user_sync3        (kat_adc0_user_sync3),
     .user_outofrange0  (kat_adc0_user_outofrange0),
     .user_outofrange1  (kat_adc0_user_outofrange1),
     .user_data_valid   (kat_adc0_user_data_valid),
  
     .mmcm_reset        (kat_adc0_mmcm_reset),
  
     .ctrl_reset        (kat_adc0_adc_reset),
     .ctrl_clk_in       (kat_adc0_clk),
     .ctrl_clk_out      (kat_adc0_clk),
     .ctrl_clk90_out    (kat_adc0_clk90_out),
     .ctrl_clk180_out   (kat_adc0_clk180_out),
     .ctrl_clk270_out   (kat_adc0_clk270_out),
     .ctrl_mmcm_locked  (kat_adc0_mmcm_locked),
  
     .mmcm_psclk        (kat_adc0_psclk),
     .mmcm_psen         (kat_adc0_psen),
     .mmcm_psincdec     (kat_adc0_psincdec),
     .mmcm_psdone       (kat_adc0_psdone)
  );

  spi_controller
  #(
     .C_BASEADDR    (),
     .C_HIGHADDR    (),
     .C_WB_AWIDTH   (),
     .C_WB_DWIDTH   (),
     .C_FAMILY      (),
     .INTERLEAVED_0 (),
     .INTERLEAVED_1 (),
     .AUTOCONFIG_0  (),
     .AUTOCONFIG_1  ()
  ) spi_controller_1 (
     .wb_clk_i             (epb_clk),
     .wb_rst_i             (wbm_rst_i),
     .wb_we_i              (wbs_we_o),
     .wb_cyc_i             (wbs_cyc_o[1]),
     .wb_stb_i             (wbs_stb_o[1]),
     .wb_sel_i             (wbs_sel_o),
     .wb_adr_i             (wbs_adr_o),
     .wb_dat_i             (wbs_dat_o),
     .wb_dat_o             (wbs_dat_i[63:32]),
     .wb_ack_o             (wbs_ack_i[1]),
     .adc0_adc3wire_clk    (kat_adc0_spi_clk),
     .adc0_adc3wire_data   (kat_adc0_spi_data),
     .adc0_adc3wire_strobe (kat_adc0_spi_cs),
     .adc0_adc_reset       (kat_adc0_adc_reset),
     .adc0_mmcm_reset      (kat_adc0_mmcm_reset),
     .adc0_psclk           (kat_adc0_psclk),
     .adc0_psen            (kat_adc0_psen),
     .adc0_psincdec        (kat_adc0_psincdec),
     .adc0_psdone          (kat_adc0_psdone),
     .adc0_clk             (kat_adc0_clk),
     .adc1_adc3wire_clk    (kat_adc_spi_controller_adc1_adc3wire_clk),
     .adc1_adc3wire_data   (kat_adc_spi_controller_adc1_adc3wire_data),
     .adc1_adc3wire_strobe (kat_adc_spi_controller_adc1_adc3wire_strobe),
     .adc1_adc_reset       (kat_adc_spi_controller_adc1_adc_reset),
     .adc1_mmcm_reset      (kat_adc_spi_controller_adc1_mmcm_reset),
     .adc1_psclk           (kat_adc_spi_controller_adc1_psclk),
     .adc1_psen            (kat_adc_spi_controller_adc1_psen),
     .adc1_psincdec        (kat_adc_spi_controller_adc1_psincdec),
     .adc1_psdone          (kat_adc_spi_controller_adc1_psdone),
     .adc1_clk             (kat_adc_spi_controller_adc1_clk)
  );


  iic_controller #(
     .C_BASEADDR  (0),
     .C_HIGHADDR  (0),
     .C_WB_AWIDTH (32),
     .C_WB_DWIDTH (32),
     .IIC_FREQ    (100),
     .CORE_FREQ   (100000),
     .EN_GAIN     (0)
  ) iic_controller_1 (
     .wb_clk_i   (epb_clk),
     .wb_rst_i   (wbm_rst_i),
     .wb_we_i    (wbs_we_o),
     .wb_cyc_i   (wbs_cyc_o[2]),
     .wb_stb_i   (wbs_stb_o[2]),
     .wb_sel_i   (wbs_sel_o),
     .wb_adr_i   (wbs_adr_o),
     .wb_dat_i   (wbs_dat_o),
     .wb_dat_o   (wbs_dat_i[95:64]),
     .wb_ack_o   (wbs_ack_i[2]),

     .xfer_done  (),

     .sda_i      (iic_sda_i),
     .sda_o      (iic_sda_o),
     .sda_t      (iic_sda_t),
     .scl_i      (iic_scl_i),
     .scl_o      (iic_scl_o),
     .scl_t      (iic_scl_t),

     .app_clk    (kat_adc_iic_controller_app_clk),
     .gain_load  (1),
     .gain_value (1)
  );



  assign debug_regin_1 = 32'hdead_0001;
  assign debug_regin_2 = 32'hdead_0002;
  assign debug_regin_3 = 32'hdead_0003;
  assign debug_regin_4 = 32'hdead_0004;
  assign debug_regin_5 = 32'hdead_0005;
  assign debug_regin_6 = 32'hdead_0006;
  assign debug_regin_7 = 32'hdead_0007;


endmodule
