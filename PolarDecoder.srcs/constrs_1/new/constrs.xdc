# Clock Constraints.
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name CLK -waveform {0.000 3.300} [get_ports clk]

# decoded bits.
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33}    [get_ports {reset}]
set_property -dict {PACKAGE_PIN K3 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[0]]
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[1]]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[2]]
set_property -dict {PACKAGE_PIN K6 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[3]]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[4]]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[5]]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[6]]
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33}     [get_ports decoded_bits[7]]

# UART Tx and Rx.
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports {Rx_Serial}]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports {Tx_Serial}]


#Debug pins.
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports {D[0]}]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {D[1]}]
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports {D[2]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {D[3]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {D[4]}]
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports {D[5]}]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports {D[6]}]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {D[7]}]

# Debug inputs.
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS33} [get_ports {SW[0]}]
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports {SW[1]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {SW[2]}]

