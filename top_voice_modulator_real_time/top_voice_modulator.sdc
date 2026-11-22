# ==============================================================================
# Restrições de Timing (Timing Analyzer) - Modulador de Voz DE2-115
# ==============================================================================

# 1. Clock Principal da placa: 50 MHz (período de 20.000 ns)
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# 2. Deriva automaticamente os 3 clocks da audio_pll (c0, c1, c2)
derive_pll_clocks

# Calcula margens de jitter e incerteza da Cyclone IV E
derive_clock_uncertainty

# 3. Isola o domínio de CLOCK_50 e as 3 saídas da PLL que passam pelo MUX
set_clock_groups -asynchronous \
    -group [get_clocks {CLOCK_50}] \
    -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[0]}] \
    -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[1]}] \
    -group [get_clocks {*|altpll_component|auto_generated|pll1|clk[2]}]

# 4. Entradas Assíncronas (Botão de Reset, Replay e Chaves de Modo)
set_false_path -from [get_ports {KEY0}]
set_false_path -from [get_ports {KEY1}]
set_false_path -from [get_ports {SW[*]}]

# 5. Interface SD Card (opera com clock dividido internamente)
set_false_path -to   [get_ports {SD_CLK}]
set_false_path -from [get_ports {SD_CMD}]
set_false_path -to   [get_ports {SD_CMD}]
set_false_path -from [get_ports {SD_DAT0}]

# 6. Codec de Áudio WM8731 (MCLK, I2S Tx/Rx e I2C)
set_false_path -to   [get_ports {AUD_XCK}]
set_false_path -to   [get_ports {AUD_BCLK}]
set_false_path -to   [get_ports {AUD_DACLRCK}]
set_false_path -to   [get_ports {AUD_ADCLRCK}]
set_false_path -to   [get_ports {AUD_DACDAT}]
set_false_path -from [get_ports {AUD_ADCDAT}]
set_false_path -to   [get_ports {I2C_SCLK}]
set_false_path -from [get_ports {I2C_SDAT}]
set_false_path -to   [get_ports {I2C_SDAT}]

# 7. Saídas de Diagnóstico Visual (LEDs, Displays 7-Seg e LCD 16x2)
set_false_path -to [get_ports {LEDR[*]}]
set_false_path -to [get_ports {HEX*[*]}]
set_false_path -to [get_ports {LCD_DATA[*] LCD_RW LCD_EN LCD_RS LCD_ON LCD_BLON}]