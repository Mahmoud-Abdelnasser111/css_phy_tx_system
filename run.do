vsim -voptargs=+acc work.css_phy_tx_1mbps_top_tb
add wave -position insertpoint  \
sim:/css_phy_tx_1mbps_top_tb/PAYLOAD_BYTES \
sim:/css_phy_tx_1mbps_top_tb/GOLDEN_SAMPLES \
sim:/css_phy_tx_1mbps_top_tb/clk \
sim:/css_phy_tx_1mbps_top_tb/reset \
sim:/css_phy_tx_1mbps_top_tb/start_Tx \
sim:/css_phy_tx_1mbps_top_tb/payloadLength \
sim:/css_phy_tx_1mbps_top_tb/payload_wr_en \
sim:/css_phy_tx_1mbps_top_tb/payload_wr_addr \
sim:/css_phy_tx_1mbps_top_tb/payload_wr_data \
sim:/css_phy_tx_1mbps_top_tb/Tx_real \
sim:/css_phy_tx_1mbps_top_tb/Tx_imag \
sim:/css_phy_tx_1mbps_top_tb/Tx_valid \
sim:/css_phy_tx_1mbps_top_tb/done_Tx \
sim:/css_phy_tx_1mbps_top_tb/payload_mem \
sim:/css_phy_tx_1mbps_top_tb/tx_real_golden \
sim:/css_phy_tx_1mbps_top_tb/tx_imag_golden \
sim:/css_phy_tx_1mbps_top_tb/payload_file \
sim:/css_phy_tx_1mbps_top_tb/tx_real_file \
sim:/css_phy_tx_1mbps_top_tb/tx_imag_file \
sim:/css_phy_tx_1mbps_top_tb/rtl_real_dump_file \
sim:/css_phy_tx_1mbps_top_tb/rtl_imag_dump_file \
sim:/css_phy_tx_1mbps_top_tb/i \
sim:/css_phy_tx_1mbps_top_tb/sample_count \
sim:/css_phy_tx_1mbps_top_tb/error_count \
sim:/css_phy_tx_1mbps_top_tb/timeout_count 
run -all