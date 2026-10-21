// ==============================================================================
// Arquivo  : tb_fir_mac.v
// Pasta    : sim/tb_fir_mac/
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Validação funcional de fir_mac + fir_rom via Resposta ao Impulso
//            Exibe os coeficientes em Hexadecimal para conferência direta com .hex
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================

`timescale 1ns / 1ps

module tb_fir_mac;

    // --------------------------------------------------------------------------
    // 1. Sinais de Teste
    // --------------------------------------------------------------------------
    reg        clk;
    reg        rst_n;

    reg  signed [15:0] sample_in;
    reg                sample_valid;
    reg                sel_filter;   // 0 = Hélio, 1 = Darth Vader

    wire [6:0]         coeff_addr;
    wire signed [15:0] coeff_data;
    wire signed [15:0] sample_out;
    wire               out_valid;
    wire               busy;

    integer tap_idx;
    integer n;

    // --------------------------------------------------------------------------
    // 2. Instanciação do Motor de Cálculo (fir_mac)
    // --------------------------------------------------------------------------
    fir_mac #(
        .NUM_TAPS   (101),
        .ADDR_WIDTH (7)
    ) u_mac (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .coeff_addr   (coeff_addr),
        .coeff_data   (coeff_data),
        .sample_out   (sample_out),
        .out_valid    (out_valid),
        .busy         (busy)
    );

    // --------------------------------------------------------------------------
    // 3. Instanciação da ROM de Coeficientes (fir_rom)
    // --------------------------------------------------------------------------
    fir_rom #(
        .NUM_TAPS   (101),
        .ADDR_WIDTH (7),
        .FILE_HELIO ("../../rtl/rom/fir_helio.hex"),
        .FILE_VADER ("../../rtl/rom/fir_vader.hex")
    ) u_rom (
        .addr       (coeff_addr),
        .sel_filter (sel_filter),
        .coeff_data (coeff_data)
    );

    // --------------------------------------------------------------------------
    // 4. Gerador de Clock de 50 MHz (Período de 20 ns)
    // --------------------------------------------------------------------------
    always #10 clk = ~clk;

    // --------------------------------------------------------------------------
    // 5. Tarefa para Injetar Amostra e Aguardar Término do Cálculo
    // --------------------------------------------------------------------------
    task send_sample;
        input signed [15:0] val;
        begin
            @(posedge clk);
            sample_in    <= val;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            sample_in    <= 16'd0;

            // Aguarda o término da convolução de 101 taps do MAC
            @(posedge out_valid);
            
            // Intervalo de guarda entre amostras simulando a taxa de 44.1 kHz
            repeat (150) @(posedge clk);
        end
    endtask

    // --------------------------------------------------------------------------
    // 6. Monitor com Hexadecimal em Destaque
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (out_valid) begin
            $display("   tap[%3d] -> HEX: %04X  |  DEC: %6d", tap_idx, sample_out, sample_out);
            tap_idx = tap_idx + 1;
        end
    end

    // --------------------------------------------------------------------------
    // 7. Sequência Principal de Teste
    // --------------------------------------------------------------------------
    initial begin
        $display("=============================================================");
        $display("[TESTBENCH] INICIANDO RESPOSTA AO IMPULSO COMPLETA (FIR 101)");
        $display("=============================================================");

        clk          = 0;
        rst_n        = 0;
        sample_in    = 0;
        sample_valid = 0;
        sel_filter   = 0;
        tap_idx      = 0;

        // Pulso de reset inicial
        #100;
        rst_n = 1;
        #200;

        // ----------------------------------------------------------------------
        // FASE 1: FILTRO HÉLIO (Passa-Alta 600 Hz)
        // ----------------------------------------------------------------------
        $display("\n=============================================================");
        $display(">>> [1/2] COEFICIENTES: FILTRO HELIO (sel_filter = 0)");
        $display("=============================================================");
        sel_filter = 0;
        tap_idx    = 0;

        // Injeta impulso unitário (máximo em Q15: +32767)
        send_sample(16'sh7FFF);

        // Injeta 100 amostras de silêncio para extrair os 101 coeficientes
        for (n = 1; n <= 100; n = n + 1) begin
            send_sample(16'sh0000);
        end

        // Intervalo entre os filtros
        repeat (500) @(posedge clk);

        // ----------------------------------------------------------------------
        // FASE 2: FILTRO DARTH VADER (Passa-Baixa 1.6 kHz)
        // ----------------------------------------------------------------------
        $display("\n=============================================================");
        $display(">>> [2/2] COEFICIENTES: FILTRO DARTH VADER (sel_filter = 1)");
        $display("=============================================================");
        sel_filter = 1;
        tap_idx    = 0;

        // Injeta impulso unitário
        send_sample(16'sh7FFF);

        // Injeta 100 amostras de silêncio
        for (n = 1; n <= 100; n = n + 1) begin
            send_sample(16'sh0000);
        end

        $display("\n=============================================================");
        $display("[TESTBENCH] TESTE CONCLUIDO COM SUCESSO!");
        $display("=============================================================");
        #1000;
        $stop;
    end

endmodule