## Generated SDC file "fir_mac.out.sdc"

## Copyright (C) 2025  Altera Corporation. All rights reserved.
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, the Altera Quartus Prime License Agreement,
## the Altera IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Altera and sold by Altera or its authorized distributors.  Please
## refer to the Altera Software License Subscription Agreements 
## on the Quartus Prime software download page.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 25.1std.0 Build 1129 10/21/2025 SC Lite Edition"

## DATE    "Wed Oct 21 13:41:27 2026"

##
## DEVICE  "EP4CE6E22C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {clk}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[0]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[1]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[2]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[3]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[4]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[5]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[6]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[7]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[8]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[9]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[10]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[11]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[12]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[13]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[14]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_data[15]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {rst_n}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[0]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[1]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[2]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[3]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[4]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[5]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[6]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[7]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[8]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[9]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[10]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[11]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[12]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[13]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[14]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_in[15]}]
set_input_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_valid}]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {busy}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[0]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[1]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[2]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[3]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[4]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[5]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {coeff_addr[6]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {out_valid}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[0]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[1]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[2]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[3]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[4]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[5]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[6]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[7]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[8]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[9]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[10]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[11]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[12]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[13]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[14]}]
set_output_delay -add_delay  -clock [get_clocks {clk}]  1.000 [get_ports {sample_out[15]}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

