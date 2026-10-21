# ==============================================================================
# Script de Simulação: sim_fir.do
# Pasta: fpga-voice-modulator/sim/tb_fir_mac
# ==============================================================================

# 1. Cria a biblioteca local
vlib work

# 2. Compila todos os arquivos .v presentes na pasta
vlog *.v

# 3. Carrega o testbench na memória
vsim -voptargs=+acc work.tb_fir_mac

# 4. Configura a janela Wave
delete wave *

add wave -divider "CLOCK E CONTROLE"
add wave -color white   /tb_fir_mac/clk
add wave -color red     /tb_fir_mac/rst_n
add wave -color yellow  /tb_fir_mac/sel_filter
add wave -color orange  /tb_fir_mac/busy

add wave -divider "ENTRADA (IMPULSO Q15)"
add wave -radix decimal /tb_fir_mac/sample_in

add wave -divider "ROM DE COEFICIENTES"
add wave -radix unsigned /tb_fir_mac/u_mac/coeff_addr
add wave -radix decimal  /tb_fir_mac/u_mac/coeff_pipe

add wave -divider "RESPOSTA AO IMPULSO (SAIDA)"
add wave -color green   /tb_fir_mac/out_valid
add wave -color cyan -radix decimal -height 80 -format Analog-Interpolated /tb_fir_mac/sample_out

# 5. Executa a simulação completa
run -all

# 6. Ajusta o zoom para enquadrar as duas respostas
wave zoom full