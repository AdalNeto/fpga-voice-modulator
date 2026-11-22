// ==============================================================================
// Módulo   : pitch_shifter.v
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Pitch Shifter em tempo real via Buffer Circular em BRAM (2048x16),
//            dois ponteiros defasados em 180° (jan. triangular) e interp. linear
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================
`timescale 1ns / 1ps

module pitch_shifter (
    input  wire               clk,          // Clock do sistema (50 MHz)
    input  wire               rst_n,        // Reset ativo-baixo
    input  wire               enable,       // 1 = ativo (Mic), 0 = bypass (SD)
    input  wire               fx_en,        // SW[1]: 0 = Natural, 1 = Efeito
    input  wire               sel_mode,     // SW[0]: 0 = Hélio (1.56x), 1 = Vader (0.72x)
    input  wire signed [15:0] sample_in,    // Amostra vinda do i2s_rx (44,1 kHz)
    input  wire               sample_valid, // Pulso de 1 ciclo por amostra

    output reg  signed [15:0] sample_out,   // Amostra com pitch deslocado
    output reg                out_valid     // Pulso de saída para o dsp_core
);

    // --------------------------------------------------------------------------
    // 1. Passos de Leitura em Ponto Fixo Q11.12 (1.0x = 4096)
    // --------------------------------------------------------------------------
    localparam [22:0] STEP_HELIO = 23'd7469; // 1.8235x (+10,4 semitons)
    localparam [22:0] STEP_VADER = 23'd3628; // 0.8857x (-2,1 semitons)
    localparam [22:0] STEP_UNITY = 23'd4096; // 1.0000x (Natural)

    wire [22:0] step = !fx_en   ? STEP_UNITY :
                       sel_mode ? STEP_VADER : STEP_HELIO;

    // --------------------------------------------------------------------------
    // 2. Memória Circular em BRAM (2048 amostras x 16 bits -> 4 blocos M9K)
    // --------------------------------------------------------------------------
    reg signed [15:0] ram [0:2047];
    reg        [10:0] wr_ptr;
    reg        [10:0] rd_addr;
    reg signed [15:0] rd_data;

    always @(posedge clk) begin
        if (sample_valid)
            ram[wr_ptr] <= sample_in;
        rd_data <= ram[rd_addr];
    end

    // --------------------------------------------------------------------------
    // 3. Máquina de Estados de Leitura, Interpolação Linear e Crossfade
    // --------------------------------------------------------------------------
    localparam [3:0]
        S_IDLE   = 4'd0,
        S_CALC   = 4'd1,
        S_RD_A0  = 4'd2,
        S_RD_A1  = 4'd3,
        S_RD_B0  = 4'd4,
        S_RD_B1  = 4'd5,
        S_RD_B2  = 4'd6,
        S_INTERP = 4'd7,
        S_MIX    = 4'd8;

    reg [3:0]         state;
    reg [22:0]        rd_acc_a;      // Acumulador Q11.12 do Ponteiro A
    reg [10:0]        addr_a, addr_b;
    reg [11:0]        frac;
    reg [10:0]        delta_a;
    reg [10:0]        w_a, w_b;      // Pesos triangulares (w_a + w_b = 1024)

    reg signed [15:0] sample_in_reg;
    reg signed [15:0] s_a0, s_a1, s_b0, s_b1;
    reg signed [15:0] tap_a, tap_b;

    // Cálculos auxiliares de interpolação e mistura
    wire signed [16:0] diff_a   = $signed({s_a1[15], s_a1}) - $signed({s_a0[15], s_a0});
    wire signed [16:0] diff_b   = $signed({s_b1[15], s_b1}) - $signed({s_b0[15], s_b0});
    wire signed [29:0] prod_a   = diff_a * $signed({1'b0, frac});
    wire signed [29:0] prod_b   = diff_b * $signed({1'b0, frac});
    wire signed [15:0] interp_a = s_a0 + prod_a[27:12];
    wire signed [15:0] interp_b = s_b0 + prod_b[27:12];

    wire signed [27:0] mix_sum  = ($signed(tap_a) * $signed({1'b0, w_a})) +
                                  ($signed(tap_b) * $signed({1'b0, w_b}));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            wr_ptr        <= 11'd0;
            rd_acc_a      <= 23'd0;
            rd_addr       <= 11'd0;
            addr_a        <= 11'd0;
            addr_b        <= 11'd0;
            frac          <= 12'd0;
            delta_a       <= 11'd0;
            w_a           <= 11'd512;
            w_b           <= 11'd512;
            sample_in_reg <= 16'sd0;
            s_a0          <= 16'sd0;
            s_a1          <= 16'sd0;
            s_b0          <= 16'sd0;
            s_b1          <= 16'sd0;
            tap_a         <= 16'sd0;
            tap_b         <= 16'sd0;
            sample_out    <= 16'sd0;
            out_valid     <= 1'b0;
        end else begin
            out_valid <= 1'b0;

            case (state)
                // Aguarda nova amostra do microfone (já gravada na BRAM neste ciclo)
                S_IDLE: begin
                    if (sample_valid) begin
                        sample_in_reg <= sample_in;
                        wr_ptr        <= wr_ptr + 11'd1;
                        rd_acc_a      <= rd_acc_a + step;
                        state         <= S_CALC;
                    end
                end

                // Calcula endereços A/B (defasados em 1024) e pesos da janela triangular
                S_CALC: begin
                    addr_a  <= rd_acc_a[22:12];
                    addr_b  <= rd_acc_a[22:12] ^ 11'h400; // +1024 mod 2048
                    frac    <= rd_acc_a[11:0];
                    delta_a <= wr_ptr - rd_acc_a[22:12];
                    rd_addr <= rd_acc_a[22:12];
                    state   <= S_RD_A0;
                end

                // Pipeline de leitura das 4 amostras vizinhas na BRAM
                S_RD_A0: begin
                    // Calcula pesos triangulares sem descontinuidade nas bordas
                    if (delta_a == 11'd0 || delta_a == 11'd2047) begin
                        w_a <= 11'd0;
                        w_b <= 11'd1024;
                    end else if (delta_a == 11'd1023 || delta_a == 11'd1024) begin
                        w_a <= 11'd1024;
                        w_b <= 11'd0;
                    end else if (delta_a[10] == 1'b0) begin
                        w_a <= {1'b0, delta_a[9:0]};
                        w_b <= 11'd1024 - {1'b0, delta_a[9:0]};
                    end else begin
                        w_a <= 11'd1024 - {1'b0, delta_a[9:0]};
                        w_b <= {1'b0, delta_a[9:0]};
                    end

                    rd_addr <= addr_a + 11'd1;
                    state   <= S_RD_A1;
                end

                S_RD_A1: begin
                    s_a0    <= rd_data; // ram[addr_a]
                    rd_addr <= addr_b;
                    state   <= S_RD_B0;
                end

                S_RD_B0: begin
                    s_a1    <= rd_data; // ram[addr_a + 1]
                    rd_addr <= addr_b + 11'd1;
                    state   <= S_RD_B1;
                end

                S_RD_B1: begin
                    s_b0  <= rd_data; // ram[addr_b]
                    state <= S_RD_B2;
                end

                S_RD_B2: begin
                    s_b1  <= rd_data; // ram[addr_b + 1]
                    state <= S_INTERP;
                end

                // Interpolação linear fracionária em cada ponteiro
                S_INTERP: begin
                    tap_a <= interp_a;
                    tap_b <= interp_b;
                    state <= S_MIX;
                end

                // Soma ponderada (crossfade) e entrega da amostra pronta
                S_MIX: begin
                    if (enable && fx_en)
                        sample_out <= mix_sum[25:10]; // Divide por 1024
                    else
                        sample_out <= sample_in_reg;

                    out_valid <= 1'b1;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule