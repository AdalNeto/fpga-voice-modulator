#**************************************************************
# Configuração de Unidades de Tempo
#**************************************************************
set_time_format -unit ns -decimal_places 3

#**************************************************************
# 1. Definição do Clock Mestre de 50 MHz da DE2-115 (Pino Y2)
# Período: 20.000 ns, 50% duty cycle (subida em 0 ns, descida em 10 ns)
#**************************************************************
create_clock -name CLOCK_50 -period 20.000 -waveform { 0.000 10.000 } [get_ports CLOCK_50]

#**************************************************************
# 2. Incerteza do Clock (Jitter e Variações Térmicas)
# Setup: 100 ps de margem de segurança
# Hold: forçado em 0.000 ns para não criar penalidade artificial em caminhos síncronos
#**************************************************************
set_clock_uncertainty -setup 0.100 -from [get_clocks CLOCK_50] -to [get_clocks CLOCK_50]
set_clock_uncertainty -hold  0.000 -from [get_clocks CLOCK_50] -to [get_clocks CLOCK_50]

#**************************************************************
# 3. Caminhos Falsos (False Paths)
# Isola periféricos lentos/assíncronos da análise crítica de 50 MHz
#**************************************************************
set_false_path -from [get_ports {KEY*}]
set_false_path -to   [get_ports {LEDR[*]}]
set_false_path -to   [get_ports {HEX*[*]}]
set_false_path -from [get_ports {SD_*}]
set_false_path -to   [get_ports {SD_*}]