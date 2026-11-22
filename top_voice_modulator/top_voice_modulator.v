// ==============================================================================
// Módulo   : top_voice_modulator.v
// Projeto  : Modulador de Voz em FPGA (SD -> WAV -> Buffer -> DSP -> I2S + LCD)
// Placa    : Terasic DE2-115 (Cyclone IV E)
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================
`timescale 1ns / 1ps

module top_voice_modulator #(
    parameter            FILE_NAME_LEN = 9,
    parameter [52*8-1:0] FILE_NAME     = "voice.wav"
)(
    input  wire       CLOCK_50,
    input  wire       KEY0,        // Reset geral ativo-baixo (PIN_M23)
    input  wire       KEY1,        // Play/Replay ativo-baixo sem resetar PLL/Codec (PIN_M21)
    input  wire [1:0] SW,          // SW[1]: 0=Natural, 1=Efeito | SW[0]: 0=Hélio, 1=Vader

    // SD Card (Interface SD 1-bit nativa)
    output wire       SD_CLK,
    inout  wire       SD_CMD,
    input  wire       SD_DAT0,

    // Codec WM8731 (I2S e Master Clock)
    output wire       AUD_XCK,     // Master clock selecionado pela PLL (PIN_E1)
    output wire       AUD_BCLK,    // Bit clock gerado pela FPGA (PIN_F2)
    output wire       AUD_DACLRCK, // Left/Right clock DAC (PIN_E3)
    output wire       AUD_ADCLRCK, // Left/Right clock ADC (PIN_C2)
    output wire       AUD_DACDAT,  // Dados seriais de áudio (PIN_D1)

    // Configuração I2C do Codec WM8731
    output wire       I2C_SCLK,    // PIN_B7
    inout  wire       I2C_SDAT,    // PIN_A8

    // Display LCD 16x2 (Terasic DE2-115)
    output wire [7:0] LCD_DATA,
    output wire       LCD_RW,
    output wire       LCD_EN,
    output wire       LCD_RS,
    output wire       LCD_ON,
    output wire       LCD_BLON,

    // LEDs de diagnóstico (LEDR[3:0])
    output wire [3:0] LEDR,

    // Displays HEX mantidos apagados
    output wire [6:0] HEX0, HEX1, HEX2, HEX3,
    output wire [6:0] HEX4, HEX5, HEX6, HEX7
);

    wire rst_n = KEY0;

    // --------------------------------------------------------------------------
    // 0. Controle de Replay (KEY1) e Detecção de "Arquivo Não Encontrado"
    // --------------------------------------------------------------------------
    reg [1:0]  key1_sync;    // Sincronizador de 2 estágios para KEY1
    reg        key1_stable;  // Estado estabilizado após debounce
    reg        key1_prev;    // Estado anterior para detectar borda de descida
    reg [19:0] key1_cnt;     // Contador de debounce (20 ms @ 50 MHz)

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            key1_sync   <= 2'b11;
            key1_stable <= 1'b1;
            key1_prev   <= 1'b1;
            key1_cnt    <= 20'd0;
        end else begin
            key1_sync <= {key1_sync[0], KEY1};
            key1_prev <= key1_stable;

            if (key1_sync[1] != key1_stable) begin
                if (key1_cnt == 20'd1_000_000) begin
                    key1_stable <= key1_sync[1];
                    key1_cnt    <= 20'd0;
                end else begin
                    key1_cnt <= key1_cnt + 20'd1;
                end
            end else begin
                key1_cnt <= 20'd0;
            end
        end
    end

    // Pulso de 1 ciclo ao pressionar KEY1; reinicia apenas a cadeia SD/WAV/DSP
    // sem reinicializar a PLL nem a configuração I2C do codec WM8731
    wire replay_pulse = (key1_prev == 1'b1) && (key1_stable == 1'b0);
    wire sd_rst_n     = rst_n & ~replay_pulse;

    // Temporizador de 1,5 s para acusar falha caso o arquivo não exista no SD
    wire        file_found;
    reg  [26:0] search_timer;
    reg         file_not_found;

    always @(posedge CLOCK_50 or negedge sd_rst_n) begin
        if (!sd_rst_n) begin
            search_timer   <= 27'd0;
            file_not_found <= 1'b0;
        end else begin
            if (file_found) begin
                file_not_found <= 1'b0;
            end else if (search_timer == 27'd75_000_000) begin // 1,5 s @ 50 MHz
                file_not_found <= 1'b1;
            end else begin
                search_timer <= search_timer + 27'd1;
            end
        end
    end

    // --------------------------------------------------------------------------
    // 1. PLL de Áudio + MUX de Clock controlado por SW[1:0]
    // --------------------------------------------------------------------------
    wire clk_natural; // c0: 11,2903 MHz -> fs = 44,10 kHz (Voz Natural)
    wire clk_helio;   // c1: 20,5882 MHz -> fs = 80,42 kHz (Modo Hélio - 1,82x)
    wire clk_vader;   // c2: 10,0000 MHz -> fs = 39,06 kHz (Modo Vader - 0,89x)
    wire pll_locked;

    audio_pll u_audio_pll (
        .inclk0 (CLOCK_50),
        .c0     (clk_natural),
        .c1     (clk_helio),
        .c2     (clk_vader),
        .locked (pll_locked)
    );

    reg mclk_selected;
    always @(*) begin
        case (SW)
            2'b10:   mclk_selected = clk_helio;   // SW[1]=1, SW[0]=0 -> Hélio
            2'b11:   mclk_selected = clk_vader;   // SW[1]=1, SW[0]=1 -> Darth Vader
            default: mclk_selected = clk_natural; // SW[1]=0          -> Voz Natural
        endcase
    end

    assign AUD_XCK = mclk_selected;

    // --------------------------------------------------------------------------
    // 2. Inicializador I2C do Codec WM8731
    // --------------------------------------------------------------------------
    wire codec_ready;

    wm8731_config u_codec_cfg (
        .clk         (CLOCK_50),
        .rst_n       (rst_n),
        .i2c_sclk    (I2C_SCLK),
        .i2c_sdat    (I2C_SDAT),
        .config_done (codec_ready)
    );

    // --------------------------------------------------------------------------
    // 3. Leitor SD Card (FAT32)
    // --------------------------------------------------------------------------
    wire [7:0] sd_byte;
    wire       sd_outen;
    wire       buf_can_read;

    sd_file_reader #(
        .FILE_NAME_LEN (FILE_NAME_LEN),
        .FILE_NAME     (FILE_NAME),
        .CLK_DIV       (3'd2),
        .SIMULATE      (0)
    ) u_sd_reader (
        .rstn            (sd_rst_n),
        .clk             (CLOCK_50),
        .sdclk           (SD_CLK),
        .sdcmd           (SD_CMD),
        .sddat0          (SD_DAT0),
        .card_stat       (),
        .card_type       (),
        .filesystem_type (),
        .file_found      (file_found),
        .can_read        (buf_can_read),
        .outen           (sd_outen),
        .outbyte         (sd_byte)
    );

    // --------------------------------------------------------------------------
    // 4. Extrator WAV (PCM 16 bits little-endian)
    // --------------------------------------------------------------------------
    wire [15:0] wav_sample;
    wire        wav_valid, wav_done;

    wav_reader u_wav_reader (
        .clk          (CLOCK_50),
        .rst_n        (sd_rst_n),
        .restart      (replay_pulse),
        .byte_in      (sd_byte),
        .byte_valid   (sd_outen),
        .sample_out   (wav_sample),
        .sample_valid (wav_valid),
        .stream_done  (wav_done)
    );

    // --------------------------------------------------------------------------
    // 5. FIFO de Desacoplamento (wav_buffer)
    // --------------------------------------------------------------------------
    wire signed [15:0] buf_sample;
    wire               buf_valid;
    wire               playable, finished;
    wire               sample_req;
    wire               rd_en = sample_req & playable & ~finished;

    wav_buffer #(
        .ADDR_W(10),
        .SECTOR_SAMPLES(256),
        .PRIME_SAMPLES(256)
    ) u_wav_buffer (
        .clk         (CLOCK_50),
        .rst_n       (sd_rst_n),
        .wr_data     (wav_sample),
        .wr_en       (wav_valid),
        .eos         (wav_done),
        .can_read    (buf_can_read),
        .rd_en       (rd_en),
        .rd_data     (buf_sample),
        .rd_valid    (buf_valid),
        .playable    (playable),
        .finished    (finished),
        .level       (),
        .overrun     (),
        .underrun    ()
    );

    // --------------------------------------------------------------------------
    // 6. Núcleo DSP (FIR + tanh + Comb) e Bypass para Voz Natural
    // --------------------------------------------------------------------------
    reg signed [15:0] held_sample;
    always @(posedge CLOCK_50 or negedge sd_rst_n) begin
        if (!sd_rst_n)
            held_sample <= 16'sd0;
        else if (finished)
            held_sample <= 16'sd0;
        else if (buf_valid)
            held_sample <= buf_sample;
    end

    wire signed [15:0] dsp_sample_out;
    wire               dsp_out_valid;

    dsp_core #(
        .FILE_HELIO ("fir_helio.hex"),
        .FILE_VADER ("fir_vader.hex"),
        .FILE_TANH  ("tanh_lut.hex")
    ) u_dsp_core (
        .clk          (CLOCK_50),
        .rst_n        (sd_rst_n),
        .sel_mode     (SW[0]),          // 0 = Hélio, 1 = Darth Vader
        .sample_in    (buf_sample),
        .sample_valid (buf_valid),
        .busy         (),
        .sample_out   (dsp_sample_out),
        .out_valid    (dsp_out_valid)
    );

    // SW[1] = 0 -> áudio limpo (held_sample) | SW[1] = 1 -> áudio filtrado (dsp_core)
    wire signed [15:0] selected_audio = SW[1] ? dsp_sample_out : held_sample;
    wire signed [15:0] audio_to_tx    = (playable & ~finished) ? selected_audio : 16'sd0;

    // --------------------------------------------------------------------------
    // 7. Transmissor I2S para o Codec WM8731
    // --------------------------------------------------------------------------
    i2s_tx #(
        .RATIO(256)
    ) u_tx (
        .clk         (CLOCK_50),
        .rst_n       (rst_n),
        .mclk        (mclk_selected),
        .pll_locked  (pll_locked),
        .sample_in   (audio_to_tx),
        .sample_req  (sample_req),
        .AUD_BCLK    (AUD_BCLK),
        .AUD_DACLRCK (AUD_DACLRCK),
        .AUD_ADCLRCK (AUD_ADCLRCK),
        .AUD_DACDAT  (AUD_DACDAT)
    );

    // --------------------------------------------------------------------------
    // 8. Controlador do Display LCD 16x2
    // --------------------------------------------------------------------------
    lcd_controller u_lcd (
        .clk            (CLOCK_50),
        .rst_n          (rst_n),
        .sw             (SW),
        .file_found     (file_found),
        .file_not_found (file_not_found),
        .finished       (finished),
        .LCD_DATA       (LCD_DATA),
        .LCD_RW         (LCD_RW),
        .LCD_EN         (LCD_EN),
        .LCD_RS         (LCD_RS),
        .LCD_ON         (LCD_ON),
        .LCD_BLON       (LCD_BLON)
    );

    // --------------------------------------------------------------------------
    // 9. LEDs de Diagnóstico e Displays HEX Apagados
    // --------------------------------------------------------------------------
    assign LEDR[0] = file_found;  // 1 = voice.wav encontrado no SD
    assign LEDR[1] = playable;    // 1 = FIFO pré-carregada e tocando
    assign LEDR[2] = codec_ready; // 1 = Codec WM8731 configurado via I2C
    assign LEDR[3] = finished;    // 1 = Reprodução concluída

    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign HEX6 = 7'b1111111;
    assign HEX7 = 7'b1111111;

endmodule