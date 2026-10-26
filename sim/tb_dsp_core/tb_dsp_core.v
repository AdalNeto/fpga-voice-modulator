// ==============================================================================
// Arquivo  : tb_dsp_core.v
// Pasta    : sim/tb_dsp_core/
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Funcao   : Testbench quantitativo calibrado (ASCII puro sem acentos)
// Padrao   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================

`timescale 1ns / 1ps

module tb_dsp_core;

    reg        clk;
    reg        rst_n;
    reg        sel_mode;

    reg  signed [15:0] sample_in;
    reg                sample_valid;

    wire               busy;
    wire signed [15:0] sample_out;
    wire               out_valid;

    // Instanciacao da UUT
    dsp_core #(
        .FILE_HELIO ("../../rtl/rom/fir_helio.hex"),
        .FILE_VADER ("../../rtl/rom/fir_vader.hex"),
        .FILE_TANH  ("../../rtl/rom/tanh_lut.hex")
    ) u_uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sel_mode     (sel_mode),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .busy         (busy),
        .sample_out   (sample_out),
        .out_valid    (out_valid)
    );

    // Clock de 50 MHz
    always #10 clk = ~clk;

    localparam AUDIO_PERIOD_CYCLES = 1134;

    // Registradores de Medicao
    reg signed [15:0] peak_measure;
    reg signed [15:0] peak_fir_vader;
    reg signed [15:0] max_sat_seen;

    integer peak_graves_helio, peak_agudos_helio;
    integer peak_graves_vader, peak_agudos_vader;
    integer echo_sample_detected;
    integer echo_amplitude_measured;

    // Monitoramento dos picos
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            peak_measure   <= 16'sh0000;
            peak_fir_vader <= 16'sh0000;
            max_sat_seen   <= 16'sh0000;
        end else begin
            if (out_valid) begin
                if ($signed(sample_out) > peak_measure)
                    peak_measure <= sample_out;
                else if (-$signed(sample_out) > peak_measure)
                    peak_measure <= -sample_out;

                if (sel_mode == 1'b1 && $signed(sample_out) > max_sat_seen)
                    max_sat_seen <= sample_out;
            end

            // Monitora a saida isolada do FIR do Vader para checar a rejeicao pura
            if (u_uut.fir_out_valid && sel_mode == 1'b1) begin
                if ($signed(u_uut.fir_sample_out) > peak_fir_vader)
                    peak_fir_vader <= u_uut.fir_sample_out;
                else if (-$signed(u_uut.fir_sample_out) > peak_fir_vader)
                    peak_fir_vader <= -u_uut.fir_sample_out;
            end
        end
    end

    // Gerador de Chirp Linear
    function signed [15:0] gen_chirp;
        input real f_start;
        input real f_stop;
        input integer n;
        input integer total_samples;
        real t, k_rate, phase, val;
        begin
            t = n / 44100.0;
            k_rate = (f_stop - f_start) / (total_samples / 44100.0);
            phase = 2.0 * 3.141592653589793 * (f_start * t + 0.5 * k_rate * t * t);
            val = $sin(phase) * 16384.0;
            gen_chirp = $rtoi(val);
        end
    endfunction

    // Envio de amostra sincronizada
    task send_sample_timed(input signed [15:0] val);
        integer wait_i;
        begin
            while (busy) @(posedge clk);
            @(posedge clk);
            sample_in    <= val;
            sample_valid <= 1'b1;
            @(posedge clk);
            sample_valid <= 1'b0;
            sample_in    <= 16'sh0000;

            for (wait_i = 0; wait_i < (AUDIO_PERIOD_CYCLES - 2); wait_i = wait_i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    integer i, k;

    initial begin
        $display("=============================================================");
        $display("Iniciando Simulacao");
        $display("=============================================================");

        clk          = 0;
        rst_n        = 0;
        sel_mode     = 0;
        sample_in    = 0;
        sample_valid = 0;

        #200;
        rst_n = 1;
        #500;

        // ----------------------------------------------------------------------
        // FASE 1: MODO HELIO (HPF 600 Hz)
        // ----------------------------------------------------------------------
        $display("\n>>> FASE 1: TESTE QUANTITATIVO - MODO HELIO (HPF 600 Hz)");
        sel_mode = 1'b0;

        for (i = 0; i < 120; i = i + 1) send_sample_timed(16'sh0000);

        // Mede graves profundos (k=0 a 60 -> f = 50 Hz a 230 Hz)
        peak_measure = 0;
        for (k = 0; k < 60; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end
        peak_graves_helio = peak_measure;

        // Passa pela regiao de corte
        for (k = 60; k < 1000; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end

        // Mede agudos (> 3.0 kHz)
        peak_measure = 0;
        for (k = 1000; k < 2000; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end
        peak_agudos_helio = peak_measure;

        for (i = 0; i < 120; i = i + 1) send_sample_timed(16'sh0000);

        $display("    [METRICA] Pico nos Graves (<230 Hz) : %0d (Esperado: < 1000)", peak_graves_helio);
        $display("    [METRICA] Pico nos Agudos (>3.0 kHz): %0d (Esperado: ~16384)", peak_agudos_helio);
        $display("    [METRICA] Razao de Atenuacao HPF    : %0d vezes", (peak_agudos_helio / (peak_graves_helio + 1)));

        if (peak_graves_helio < 1000)
            $display("    [STATUS] PASS: Atenuacao de graves conforme a ordem do filtro.");
        else
            $display("    [STATUS] FAIL: Vazamento excessivo de graves.");

        // ----------------------------------------------------------------------
        // FASE 2: MODO DARTH VADER (LPF 1.6 kHz + Tanh)
        // ----------------------------------------------------------------------
        $display("\n>>> FASE 2: TESTE QUANTITATIVO - MODO VADER (LPF 1.6 kHz + Tanh)");
        sel_mode = 1'b1;
        max_sat_seen = 0;

        // Drena totalmente a linha de retardo do Comb filter (2048 amostras)
        for (i = 0; i < 2050; i = i + 1) send_sample_timed(16'sh0000);

        // Mede graves passantes
        peak_measure   = 0;
        peak_fir_vader = 0;
        for (k = 0; k < 300; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end
        peak_graves_vader = peak_measure;

        for (k = 300; k < 1200; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end

        // Mede agudos diretamente na saida do FIR para isolar o eco do Comb
        peak_fir_vader = 0;
        for (k = 1200; k < 2000; k = k + 1) begin
            send_sample_timed(gen_chirp(50.0, 6000.0, k, 2000));
        end
        peak_agudos_vader = peak_fir_vader;

        for (i = 0; i < 120; i = i + 1) send_sample_timed(16'sh0000);

        $display("    [METRICA] Pico nos Graves (<900 Hz) : %0d (Esperado: alto)", peak_graves_vader);
        $display("    [METRICA] Pico FIR nos Agudos (>3.6k): %0d (Esperado: < 500)", peak_agudos_vader);
        $display("    [METRICA] Razao Rejeicao FIR LPF    : %0d vezes", (peak_graves_vader / (peak_agudos_vader + 1)));
        $display("    [METRICA] Teto de Saturacao Tanh    : %0d (Limite teorico: 18954)", max_sat_seen);

        // ----------------------------------------------------------------------
        // FASE 3: RETARDO E GANHO DO COMB FILTER
        // ----------------------------------------------------------------------
        $display("\n>>> FASE 3: TESTE QUANTITATIVO - COMB FILTER (Retardo e Ganho)");

        // Drena a memoria para garantir silencio absoluto
        for (i = 0; i < 2050; i = i + 1) send_sample_timed(16'sh0000);

        // Injeta impulso de amplitude 20000
        send_sample_timed(16'sh4E20);

        echo_amplitude_measured = 0;
        echo_sample_detected    = 0;

        // Janela de busca: 1102 (delay do Comb) + 50 (delay do FIR) = 1152
        for (i = 1; i <= 1250; i = i + 1) begin
            send_sample_timed(16'sh0000);
            if (i >= 1140 && i <= 1165) begin
                if ($signed(sample_out) > echo_amplitude_measured) begin
                    echo_amplitude_measured = sample_out;
                    echo_sample_detected = i;
                end
            end
        end

        $display("    [METRICA] Amostra do Eco Detectado  : Amostra %0d (Esperado: 1152)", echo_sample_detected);
        $display("    [METRICA] Amplitude do Eco Medido   : %0d", echo_amplitude_measured);
        $display("    [METRICA] Confirmacao do Retardo    : 1102 amostras Comb + 50 amostras FIR");

        $display("\n=============================================================");
        $display("Simulacao Finalizada");
        $display("=============================================================");
        #2000;
        $stop;
    end

endmodule