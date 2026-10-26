## Generated SDC file "dsp_core.out.sdc"

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

## DATE    "Mon Oct 26 02:45:06 2026"

##
## DEVICE  "EP4CE115F29C7"
##


# ==============================================================================
# Arquivo : dsp_core.sdc
# Projeto : Modulador de Voz em FPGA (Cyclone IV EP4CE115F29C7)
# ==============================================================================

set_time_format -unit ns -decimal_places 3

# ------------------------------------------------------------------------------
# 1. Definição do Clock Principal (50 MHz = período de 20.0 ns)
# ------------------------------------------------------------------------------
create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]

# Incerteza do clock (Jitter típico do oscilador da DE2-115)
derive_clock_uncertainty

# ------------------------------------------------------------------------------
# 2. Atrasos de Entrada (Apenas para sinais síncronos de dados)
# ------------------------------------------------------------------------------
set_input_delay -clock [get_clocks {clk}] 2.000 [get_ports {sample_valid}]
set_input_delay -clock [get_clocks {clk}] 2.000 [get_ports {sample_in[*]}]

# ------------------------------------------------------------------------------
# 3. Atrasos de Saída (Sinais síncronos entregues na saída)
# ------------------------------------------------------------------------------
set_output_delay -clock [get_clocks {clk}] 2.000 [get_ports {busy}]
set_output_delay -clock [get_clocks {clk}] 2.000 [get_ports {out_valid}]
set_output_delay -clock [get_clocks {clk}] 2.000 [get_ports {sample_out[*]}]

# ------------------------------------------------------------------------------
# 4. Caminhos Falsos (Sinais assíncronos e chaves manuais)
# ------------------------------------------------------------------------------
# Reset vindo de botão mecânico (KEY0)
set_false_path -from [get_ports {rst_n}]

# Chave seletora estática de modo (SW0)
set_false_path -from [get_ports {sel_mode}]