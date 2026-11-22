// ==============================================================================
// Módulo   : i2s_rx.v
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Receptor I2S (ADC do Codec WM8731 -> Amostra PCM 16-bit signed)
//            Sincronizado com CLOCK_50, captura o canal esquerdo (ADCLRCK = 0)
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================
`timescale 1ns / 1ps

module i2s_rx (
    input  wire               clk,          // Clock do sistema (50 MHz)
    input  wire               rst_n,        // Reset ativo-baixo

    // Interface I2S vinda do i2s_tx e do codec WM8731
    input  wire               AUD_BCLK,     // Bit clock gerado pelo i2s_tx
    input  wire               AUD_ADCLRCK,  // Left/Right clock do ADC
    input  wire               AUD_ADCDAT,   // Dados seriais do microfone (PIN_D2)

    // Saída paralela para o núcleo DSP
    output reg  signed [15:0] sample_out,   // Amostra capturada (INT16)
    output reg                sample_valid  // Pulso de 1 ciclo por amostra pronta
);

    // --------------------------------------------------------------------------
    // 1. Sincronizadores de Entrada (Domínio AUD_XCK -> Domínio CLOCK_50)
    // --------------------------------------------------------------------------
    reg [2:0] bclk_sync;
    reg [1:0] lrck_sync;
    reg [1:0] dat_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_sync <= 3'b000;
            lrck_sync <= 2'b00;
            dat_sync  <= 2'b00;
        end else begin
            bclk_sync <= {bclk_sync[1:0], AUD_BCLK};
            lrck_sync <= {lrck_sync[0],   AUD_ADCLRCK};
            dat_sync  <= {dat_sync[0],    AUD_ADCDAT};
        end
    end

    // Detecção de borda de subida do BCLK e valores sincronizados
    wire bclk_rise = (bclk_sync[2:1] == 2'b01);
    wire lrck_val  = lrck_sync[1];
    wire dat_val   = dat_sync[1];

    // --------------------------------------------------------------------------
    // 2. Máquina de Estados de Recepção I2S Padrão (1 BCLK de atraso após LRCK)
    // --------------------------------------------------------------------------
    localparam [1:0]
        ST_WAIT_HIGH = 2'd0, // Aguarda canal direito (ADCLRCK = 1) para sincronizar
        ST_WAIT_LOW  = 2'd1, // Aguarda início do canal esquerdo (ADCLRCK = 0)
        ST_SHIFT     = 2'd2; // Desloca os 16 bits (MSB -> LSB)

    reg [1:0]  state;
    reg [3:0]  bit_cnt;
    reg [15:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_WAIT_HIGH;
            bit_cnt      <= 4'd0;
            shift_reg    <= 16'd0;
            sample_out   <= 16'sd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0; // Pulso de apenas 1 ciclo

            if (bclk_rise) begin
                case (state)
                    // Garante sincronismo no início do quadro esquerdo
                    ST_WAIT_HIGH: begin
                        if (lrck_val == 1'b1)
                            state <= ST_WAIT_LOW;
                    end

                    // A 1ª borda de subida do BCLK com ADCLRCK=0 é o atraso padrão I2S
                    ST_WAIT_LOW: begin
                        if (lrck_val == 1'b0) begin
                            bit_cnt <= 4'd15;
                            state   <= ST_SHIFT;
                        end
                    end

                    // Captura os 16 bits nas 16 bordas seguintes do BCLK
                    ST_SHIFT: begin
                        shift_reg <= {shift_reg[14:0], dat_val};

                        if (bit_cnt == 4'd0) begin
                            sample_out   <= {shift_reg[14:0], dat_val};
                            sample_valid <= 1'b1;
                            state        <= ST_WAIT_HIGH;
                        end else begin
                            bit_cnt <= bit_cnt - 4'd1;
                        end
                    end

                    default: state <= ST_WAIT_HIGH;
                endcase
            end
        end
    end

endmodule