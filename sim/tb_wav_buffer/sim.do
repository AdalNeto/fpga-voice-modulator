# Cria a biblioteca de trabalho
vlib work

# Compila todos os arquivos Verilog da pasta
vlog *.v

# Carrega o testbench otimizado para simulação
vsim -voptargs=+acc work.tb_top_wav_buf_test

# Limpa ondas antigas e adiciona o painel organizado de sinais
delete wave *
add wave -divider "CLOCK E RESET"
add wave /tb_top_wav_buf_test/CLOCK_50
add wave /tb_top_wav_buf_test/KEY0

add wave -divider "CONTROLE DE FLUXO (SD vs BUFFER)"
add wave -color yellow /tb_top_wav_buf_test/uut/can_read
add wave -color cyan -radix unsigned /tb_top_wav_buf_test/uut/level
add wave /tb_top_wav_buf_test/uut/playable

add wave -divider "CONSUMIDOR 44.1 kHz"
add wave /tb_top_wav_buf_test/uut/rd_en
add wave -radix decimal /tb_top_wav_buf_test/uut/rd_data
add wave -radix unsigned /tb_top_wav_buf_test/uut/consumed

add wave -divider "DIAGNOSTICO (LEDS)"
add wave -radix binary /tb_top_wav_buf_test/LEDR
add wave /tb_top_wav_buf_test/uut/overrun
add wave /tb_top_wav_buf_test/uut/underrun

# Executa a simulação automaticamente por 15 ms
run 15 ms