// ==============================================================================
// Módulo   : tanh_lut.v
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Saturação suave não-linear: y = 0.6 * tanh(2x) com Interpolação
//            Linear por partes (256 pontos + 7 bits fracionários = 15 bits)
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================
`timescale 1ns / 1ps

module tanh_lut #(
    parameter LUT_FILE = "tanh_lut.hex"
)(
    input  wire               clk,
    input  wire               rst_n,

    input  wire signed [15:0] sample_in,
    input  wire               sample_valid,

    output reg  signed [15:0] sample_out,
    output reg                out_valid
);

    // ROM de 256 posições em lógica combinacional (evita falhas de M9K com clock-enable)
    (* romstyle = "logic" *) reg signed [15:0] lut_mem [0:255];

    initial begin
        $readmemh(LUT_FILE, lut_mem);
    end

    // Magnitude absoluta exata em complemento de dois (protege -32768)
    wire [15:0] abs_sample = sample_in[15] ? (~sample_in + 16'd1) : sample_in;
    wire [14:0] mag15      = abs_sample[15] ? 15'h7FFF : abs_sample[14:0];

    // Índice inteiro [14:7] (0..255), próximo índice e fração [6:0] (0..127)
    wire [7:0] idx0 = mag15[14:7];
    wire [7:0] idx1 = (idx0 == 8'd255) ? 8'd255 : (idx0 + 8'd1);
    wire [6:0] frac = mag15[6:0];

    // Registradores do Estágio 1
    reg               is_negative;
    reg signed [15:0] y0_reg;
    reg signed [15:0] y1_reg;
    reg        [6:0]  frac_reg;
    reg               pipe_valid;

    // Interpolação linear: y = y0 + (((y1 - y0) * frac) >>> 7)
    wire signed [16:0] diff_y      = {y1_reg[15], y1_reg} - {y0_reg[15], y0_reg};
    wire signed [7:0]  frac_s      = {1'b0, frac_reg};
    wire signed [24:0] prod_y      = diff_y * frac_s;
    wire signed [16:0] interp_step = prod_y >>> 7;
    wire signed [16:0] y_interp    = {y0_reg[15], y0_reg} + interp_step;
    wire signed [15:0] y_final     = is_negative ? -y_interp[15:0] : y_interp[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_negative <= 1'b0;
            y0_reg      <= 16'sh0000;
            y1_reg      <= 16'sh0000;
            frac_reg    <= 7'd0;
            pipe_valid  <= 1'b0;
            sample_out  <= 16'sh0000;
            out_valid   <= 1'b0;
        end else begin
            pipe_valid <= sample_valid;

            // Estágio 1: Lê dois pontos adjacentes da LUT e guarda a fração
            if (sample_valid) begin
                is_negative <= sample_in[15];
                y0_reg      <= lut_mem[idx0];
                y1_reg      <= lut_mem[idx1];
                frac_reg    <= frac;
            end

            // Estágio 2: Aplica a interpolação linear e restaura o sinal
            if (pipe_valid) begin
                sample_out <= y_final;
            end

            out_valid <= pipe_valid;
        end
    end

endmodule