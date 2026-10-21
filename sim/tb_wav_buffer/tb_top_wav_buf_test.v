`timescale 1ns / 1ps

module tb_top_wav_buf_test;

    // ------------------------------------------------------------
    // 1. Sinais de estímulo e controle
    // ------------------------------------------------------------
    reg        CLOCK_50;
    reg        KEY0;

    // Linhas físicas da interface SD
    wire       SD_CLK;
    wire       SD_CMD;
    wire       SD_DAT0;

    // Pull-ups para simulação de barramento tri-state do SD
    pullup(SD_CMD);
    pullup(SD_DAT0);

    // Diagnóstico visual
    wire [3:0] LEDR;
    wire [6:0] HEX0;
    wire [6:0] HEX1;

    // ------------------------------------------------------------
    // 2. Instanciação do circuito sob teste (UUT)
    // ------------------------------------------------------------
    top_wav_buf_test #(
        .FILE_NAME_LEN (9),
        .FILE_NAME     ("voice.wav")
    ) uut (
        .CLOCK_50 (CLOCK_50),
        .KEY0     (KEY0),
        .SD_CLK   (SD_CLK),
        .SD_CMD   (SD_CMD),
        .SD_DAT0  (SD_DAT0),
        .LEDR     (LEDR),
        .HEX0     (HEX0),
        .HEX1     (HEX1)
    );

    // ------------------------------------------------------------
    // 3. Instanciação do Mock do Cartão SD
    // ------------------------------------------------------------
    sd_card_mock u_sd_card (
        .sd_clk  (SD_CLK),
        .sd_cmd  (SD_CMD),
        .sd_dat0 (SD_DAT0)
    );

    // ------------------------------------------------------------
    // 4. Gerador de clock de 50 MHz (período de 20 ns)
    // ------------------------------------------------------------
    always #10 CLOCK_50 = ~CLOCK_50;

    // ------------------------------------------------------------
    // 5. Sequência principal de controle e tempo limite
    // ------------------------------------------------------------
    initial begin
        $display("===============================================================");
        $display("[TESTBENCH] Iniciando simulacao: SD -> FAT32 -> WAV -> BUFFER -> 44.1kHz");
        $display("===============================================================");

        CLOCK_50 = 1'b0;
        KEY0     = 1'b0; // Reset ativo em nível baixo

        // Pulso de reset de 500 ns
        #500;
        KEY0     = 1'b1; // Libera reset
        $display("[TESTBENCH @ %0t ns] Reset liberado (KEY0 = 1).", $time);

        // Tempo de simulação: 15 ms
        // Tempo suficiente para inicializar o SD, achar o arquivo, encher
        // o buffer até o limite (can_read=0), e consumir as primeiras centenas de amostras
        #15000000;

        $display("===============================================================");
        $display("[TESTBENCH @ %0t ns] Janela de simulacao concluida (15 ms).", $time);
        $display(" Status dos LEDs: 4'b%b", LEDR);
        $display("   LEDR[0] (SD pronto)      = %b", LEDR[0]);
        $display("   LEDR[1] (WAV localizado) = %b", LEDR[1]);
        $display("   LEDR[2] (ERRO Over/Under)= %b (0 = PERFEITO, 1 = ERRO)", LEDR[2]);
        $display("   LEDR[3] (Fim do audio)   = %b", LEDR[3]);
        $display("===============================================================");
        $stop;
    end

    // ------------------------------------------------------------
    // 6. Monitores concorrentes de diagnóstico
    // ------------------------------------------------------------
    initial begin
        wait(LEDR[0] === 1'b1);
        $display("[TESTBENCH @ %0t ns] [OK] LEDR[0] = 1: Cartao SD inicializado!", $time);
    end

    initial begin
        wait(LEDR[1] === 1'b1);
        $display("[TESTBENCH @ %0t ns] [OK] LEDR[1] = 1: Arquivo voice.wav localizado no FAT32!", $time);
    end

    // Monitor do buffer: se LEDR[2] subir, houve perda de amostra ou leitura com buffer vazio
    initial begin
        wait(LEDR[2] === 1'b1);
        $display("[TESTBENCH @ %0t ns] [ALERTA/ERRO] LEDR[2] = 1: Ocorreu OVERRUN ou UNDERRUN no buffer!", $time);
    end

    initial begin
        wait(LEDR[3] === 1'b1);
        $display("[TESTBENCH @ %0t ns] [SUCESSO TOTAL] LEDR[3] = 1: Arquivo inteiramente consumido!", $time);
        #1000;
        $stop;
    end

    // Monitor periódico do progresso de consumo de áudio
    always begin
        #1000000; // a cada 1 ms
        if (LEDR[1]) begin
            $display("[STATUS @ %0t ms] Buffer ocupado: %0d amostras | can_read = %b | Amostras consumidas: %0d", 
                     $time/1000000, uut.u_buf.level, uut.can_read, uut.consumed);
        end
    end

endmodule