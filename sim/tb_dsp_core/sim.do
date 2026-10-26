# Criacao da biblioteca
vlib work
vmap work work

# Compilacao dos modulos RTL
vlog -work work ../../rtl/dsp/fir_rom.v
vlog -work work ../../rtl/dsp/fir_mac.v
vlog -work work ../../rtl/dsp/tanh_lut.v
vlog -work work ../../rtl/dsp/comb_filter.v
vlog -work work ../../rtl/dsp/dsp_core.v

# Compilacao do Testbench
vlog -work work tb_dsp_core.v

# Inicializacao da simulacao
vsim -voptargs=+acc work.tb_dsp_core

# Painel de sinais
add wave -divider "CONTROLE E CLK"
add wave -color Yellow              /tb_dsp_core/clk
add wave -color Red                 /tb_dsp_core/rst_n
add wave -color "Medium Orchid"     /tb_dsp_core/sel_mode
add wave -color "Cornflower Blue"   /tb_dsp_core/busy

add wave -divider "AUDIO ENTRADA (CHIRP)"
add wave -radix decimal -color White -format Analog-Interpolated -min -32768 -max 32767 -height 70 /tb_dsp_core/sample_in
add wave -color Cyan                /tb_dsp_core/sample_valid

add wave -divider "ESTAGIOS INTERNOS"
add wave -radix decimal -color "Sandy Brown" /tb_dsp_core/u_uut/fir_sample_out
add wave -radix decimal -color Orange        /tb_dsp_core/u_uut/sat_sample_out
add wave -radix decimal -color Magenta       /tb_dsp_core/u_uut/comb_sample_out

add wave -divider "AUDIO SAIDA FINAL"
add wave -radix decimal -color Green -format Analog-Interpolated -min -32768 -max 32767 -height 70 /tb_dsp_core/sample_out
add wave -color Green               /tb_dsp_core/out_valid

# Execucao completa e ajuste de zoom
run -all
wave zoom full