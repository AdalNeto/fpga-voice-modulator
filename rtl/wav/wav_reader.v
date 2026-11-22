// ==============================================================================
// Módulo   : wav_reader.v
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Parseia o header WAV (ajustado para 78 bytes com bloco LIST),
//            extrai amostras PCM INT16 e permite reiniciar via KEY1
// Interface: Recebe stream de bytes do sd_file_reader (outen/outbyte)
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================

`timescale 1ns / 1ps

module wav_reader (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        restart,      // pulso de 1 ciclo (KEY1) para tocar novamente

    // Stream de bytes vindo do sd_file_reader
    input  wire [7:0]  byte_in,      // byte recebido
    input  wire        byte_valid,   // 1 ciclo = byte_in é válido

    // Saída de amostras PCM para o buffer/DSP
    output reg  [15:0] sample_out,   // amostra INT16 (signed, little-endian)
    output reg         sample_valid, // pulso de 1 ciclo por amostra pronta
    output reg         stream_done   // 1 = todos os bytes de dados foram lidos
);

    // -------------------------------------------------------
    // Header WAV deste arquivo (78 bytes):
    //   0..35  RIFF + WAVE + chunk "fmt "
    //  36..69  Chunk "LIST" (34 bytes de metadados Lavf)
    //  70..73  "data"
    //  74..77  tamanho dos dados PCM em bytes
    //  78+     amostras PCM
    // -------------------------------------------------------
    localparam HEADER_SIZE = 78; // Alterado de 44 para 78

    localparam [1:0]
        ST_HEADER = 2'd0,
        ST_DATA   = 2'd1,
        ST_DONE   = 2'd2;

    reg [1:0]  state;
    reg [7:0]  header_cnt;  // conta os 78 bytes do header (0..77)
    reg [31:0] data_bytes;  // total de bytes PCM extraído do header
    reg [31:0] data_read;   // bytes PCM já consumidos

    reg [7:0]  lsb_byte;    // armazena LSB enquanto aguarda MSB
    reg        lsb_valid;   // 1 = lsb_byte está aguardando MSB

    // Campos do header (opcionais — úteis para debug/validação)
    reg [15:0] num_channels;
    reg [31:0] sample_rate;
    reg [15:0] bits_per_sample;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= ST_HEADER;
            header_cnt      <= 8'd0;
            data_bytes      <= 32'd0;
            data_read       <= 32'd0;
            lsb_valid       <= 1'b0;
            sample_valid    <= 1'b0;
            stream_done     <= 1'b0;
            num_channels    <= 16'd0;
            sample_rate     <= 32'd0;
            bits_per_sample <= 16'd0;
            sample_out      <= 16'd0;
            lsb_byte        <= 8'd0;
        end else if (restart) begin
            // Reinicia apenas o parser WAV quando KEY1 é pressionado,
            // mantendo a PLL e o codec WM8731 configurados
            state           <= ST_HEADER;
            header_cnt      <= 8'd0;
            data_bytes      <= 32'd0;
            data_read       <= 32'd0;
            lsb_valid       <= 1'b0;
            sample_valid    <= 1'b0;
            stream_done     <= 1'b0;
            sample_out      <= 16'd0;
            lsb_byte        <= 8'd0;
        end else begin
            // Pulso de amostra pronta: ativo apenas 1 ciclo
            sample_valid <= 1'b0;

            if (byte_valid) begin
                case (state)

                    // ----------------------------------------
                    // ST_HEADER: consome 78 bytes, extrai campos
                    // ----------------------------------------
                    ST_HEADER: begin
                        case (header_cnt)
                            8'd22: num_channels[7:0]     <= byte_in;
                            8'd23: num_channels[15:8]    <= byte_in;
                            8'd24: sample_rate[7:0]      <= byte_in;
                            8'd25: sample_rate[15:8]     <= byte_in;
                            8'd26: sample_rate[23:16]    <= byte_in;
                            8'd27: sample_rate[31:24]    <= byte_in;
                            8'd34: bits_per_sample[7:0]  <= byte_in;
                            8'd35: bits_per_sample[15:8] <= byte_in;
                            // Deslocado de 40..43 para 74..77 devido ao chunk LIST:
                            8'd74: data_bytes[7:0]       <= byte_in;
                            8'd75: data_bytes[15:8]      <= byte_in;
                            8'd76: data_bytes[23:16]     <= byte_in;
                            8'd77: data_bytes[31:24]     <= byte_in;
                            default: ;
                        endcase

                        if (header_cnt == HEADER_SIZE - 1)
                            state <= ST_DATA;
                        else
                            header_cnt <= header_cnt + 8'd1;
                    end

                    // ----------------------------------------
                    // ST_DATA: monta amostras INT16 little-endian
                    // byte par   -> LSB (bits 7:0 da amostra)
                    // byte ímpar -> MSB (bits 15:8 da amostra) -> emite
                    // ----------------------------------------
                    ST_DATA: begin
                        if (!lsb_valid) begin
                            lsb_byte  <= byte_in;
                            lsb_valid <= 1'b1;
                        end else begin
                            sample_out   <= {byte_in, lsb_byte}; // INT16 LE
                            sample_valid <= 1'b1;
                            lsb_valid    <= 1'b0;
                            data_read    <= data_read + 32'd2;

                            if (data_read + 32'd2 >= data_bytes)
                                state <= ST_DONE;
                        end
                    end

                    // ----------------------------------------
                    // ST_DONE: mantém stream_done ativo até restart
                    // ----------------------------------------
                    ST_DONE: begin
                        stream_done <= 1'b1;
                    end

                    default: state <= ST_HEADER;

                endcase
            end

            // Mantém stream_done alto após atingido (mesmo sem byte_valid)
            if (state == ST_DONE)
                stream_done <= 1'b1;
        end
    end

endmodule