# Clock Constraints.
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name CLK -waveform {0.000 3.300} [get_ports clk]

# Input & Output
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33}    [get_ports {reset}]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[0]]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[1]]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[2]]
set_property -dict {PACKAGE_PIN K6 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[3]]