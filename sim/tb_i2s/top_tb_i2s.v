// ==============================================================================
// Integração: produtor (SD falso, rajadas de 256 c/ can_read) -> wav_buffer ->
//             dsp_core REAL (Hélio ou Vader) -> i2s_tx -> receptor I2S.
// Confere que a sequência de amostras que o dsp_core produz (1 por sample_req)
// é a que sai em L e R no I2S, sem perdas/duplicatas, e que SDATA/LRCK só mudam
// na descida do BCLK. tanh_lut.hex aqui é um placeholder (o conteúdo não afeta
// a checagem, pois compara com a saída do próprio dsp_core).
// ==============================================================================
`timescale 1ns / 1ps

module tb_integracao;
    parameter MODE  = 0;          // 0 = Hélio, 1 = Vader
    parameter RATIO = 128;        // MCLK/fs
    parameter HALF  = 49.21;      // meio período de mclk (ns)
    parameter NSAMP = 1500;       // > 1102 para exercitar o eco do comb

    reg clk = 0, mclk = 0, rst_n = 0;
    always #10     clk  = ~clk;
    always #(HALF) mclk = ~mclk;

    // ---- produtor ----
    reg  [15:0] wr_data = 0;
    reg         wr_en = 0, eos = 0;
    wire        can_read, rd_valid, playable, finished, overrun, underrun;
    wire [15:0] rd_data;
    wire [10:0] level;
    wire        req;
    wire        rd_en = req & playable & ~finished;

    wav_buffer #(.ADDR_W(10), .SECTOR_SAMPLES(256), .PRIME_SAMPLES(256)) u_buf (
        .clk(clk), .rst_n(rst_n), .wr_data(wr_data), .wr_en(wr_en), .eos(eos),
        .can_read(can_read), .rd_en(rd_en), .rd_data(rd_data), .rd_valid(rd_valid),
        .playable(playable), .finished(finished), .level(level),
        .overrun(overrun), .underrun(underrun));

    // ---- dsp_core real ----
    wire signed [15:0] dsp_y;
    wire               dsp_ov, dsp_busy;
    dsp_core #(.FILE_HELIO("../rom/fir_helio.hex"), .FILE_VADER("../rom/fir_vader.hex"),
               .FILE_TANH ("../rom/tanh_lut.hex")) u_dsp (
        .clk(clk), .rst_n(rst_n), .sel_mode(MODE[0]),
        .sample_in(rd_data), .sample_valid(rd_valid),
        .busy(dsp_busy), .sample_out(dsp_y), .out_valid(dsp_ov));

    // ---- i2s ----
    wire signed [15:0] i2s_in = (playable & ~finished) ? dsp_y : 16'sd0;
    wire bclk, lrck_d, lrck_a, sdata;
    i2s_tx #(.RATIO(RATIO)) u_if (
        .clk(clk), .rst_n(rst_n), .mclk(mclk), .pll_locked(1'b1),
        .sample_in(i2s_in), .sample_req(req),
        .AUD_BCLK(bclk), .AUD_DACLRCK(lrck_d), .AUD_ADCLRCK(lrck_a), .AUD_DACDAT(sdata));

    // ---- SD falso: rajadas de 256 amostras quando can_read=1 ----
    function integer xval; input integer i; real r;
        begin r = 12000.0*$sin(6.283185307*i/53.0) + 6000.0*$sin(6.283185307*i/11.0);
              xval = $rtoi(r); end
    endfunction
    integer wcnt = 0, burst = 0, gap = 0;
    always @(posedge clk) begin
        wr_en <= 1'b0;
        if (rst_n) begin
            if (burst > 0) begin
                wr_en <= 1'b1; wr_data <= xval(wcnt);
                wcnt <= wcnt + 1; burst <= burst - 1; gap <= 30;
                if (wcnt == NSAMP-1) eos <= 1'b1;
            end else if (gap > 0) gap <= gap - 1;
            else if (can_read && wcnt < NSAMP)
                burst <= (NSAMP - wcnt >= 256) ? 256 : (NSAMP - wcnt);
        end
    end

    // ---- referência: saídas do dsp_core, em ordem ----
    integer nref = 0; integer ref_ [0:4095];
    always @(posedge clk) if (dsp_ov) begin ref_[nref] = $signed(dsp_y); nref = nref + 1; end

    // ---- receptor I2S independente ----
    reg lrck_q = 1; integer bitcnt = 0, nl = 0, nr = 0;
    reg [15:0] acc = 0; integer rx_l [0:4095]; integer rx_r [0:4095];
    always @(posedge bclk) begin
        if (lrck_d != lrck_q) begin
            if (bitcnt >= 16) begin
                if (lrck_q == 1'b0) begin rx_l[nl] = $signed(acc); nl = nl + 1; end
                else                begin rx_r[nr] = $signed(acc); nr = nr + 1; end
            end
            bitcnt = 0; acc = 0;
        end else begin
            if (bitcnt < 16) acc = {acc[14:0], sdata};
            bitcnt = bitcnt + 1;
        end
        lrck_q = lrck_d;
    end

    // ---- SDATA/LRCK só podem mudar na descida do BCLK ----
    realtime t_fall = -1; integer viol = 0;
    always @(negedge bclk) t_fall = $realtime;
    always @(sdata or lrck_d) begin : chk
        realtime tc;
        tc = $realtime;
        #0.001;
        if (nl > 0 && t_fall != tc) viol = viol + 1;
    end

    // ---- verificação ----
    integer errors = 0, f0, best, k, mm, ncmp, nz;
    initial begin
        repeat (20) @(posedge clk); rst_n = 1;
        wait (finished);
        repeat (80) @(posedge clk);
        #(RATIO * 2.0 * HALF * 40);

        ncmp = NSAMP - 5;
        best = -1;
        for (f0 = 0; f0 < 60 && best < 0; f0 = f0 + 1) begin
            mm = 0;
            for (k = 0; k < ncmp; k = k + 1) if (rx_l[f0+k] !== ref_[k]) mm = mm + 1;
            if (mm == 0) best = f0;
        end
        if (best < 0) begin errors = errors + 1; $display("ERRO: sequencia I2S != saida do dsp_core"); end
        nz = 0;
        for (k = 0; k < ncmp; k = k + 1) begin
            if (best >= 0 && rx_r[best+k] !== rx_l[best+k]) errors = errors + 1;
            if (ref_[k] != 0) nz = nz + 1;
        end
        if (nref < NSAMP-1) begin errors = errors + 1; $display("ERRO: dsp_core produziu so %0d amostras", nref); end
        if (overrun || underrun) begin errors = errors + 1; $display("ERRO: overrun=%b underrun=%b", overrun, underrun); end
        if (viol != 0) begin errors = errors + 1; $display("ERRO: %0d mudancas de SDATA/LRCK fora da descida do BCLK", viol); end
        if (nz < ncmp/2) begin errors = errors + 1; $display("ERRO: saida quase toda zero (%0d nao-nulas)", nz); end

        $display("MODE=%0d RATIO=%0d fs=%0.2f kHz | dsp_core: %0d amostras (%0d != 0) | frames I2S L=%0d R=%0d | offset=%0d | viol=%0d",
                 MODE, RATIO, 1.0e6/(RATIO*2.0*HALF), nref, nz, nl, nr, best, viol);
        if (errors == 0) $display("PASS");
        else             $display("FAIL (%0d erros)", errors);
        $finish;
    end
    initial begin #900_000_000; $display("TIMEOUT"); $finish; end
endmodule
