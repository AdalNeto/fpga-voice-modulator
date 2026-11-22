// wav_reader.v
// Parseia o header WAV (ajustado para 78 bytes com bloco LIST) e extrai amostras PCM INT16
// Interface: recebe stream de bytes do sd_file_reader (outen/outbyte)

module wav_reader (
    input  wire        clk,
    input  wire        rst_n,

    // Stream de bytes vindo do sd_file_reader
    input  wire [7:0]  byte_in,      // byte recebido
    input  wire        byte_valid,   // 1 ciclo = byte_in eh valido

    // Saida de amostras PCM para o buffer/DSP
    output reg  [15:0] sample_out,   // amostra INT16 (signed, little-endian)
    output reg         sample_valid, // pulso de 1 ciclo por amostra pronta
    output reg         stream_done   // todos os bytes de dados foram lidos
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

localparam ST_HEADER = 2'd0;
localparam ST_DATA   = 2'd1;
localparam ST_DONE   = 2'd2;

reg [1:0]  state;
reg [7:0]  header_cnt;  // conta os 78 bytes do header (0..77)
reg [31:0] data_bytes;  // total de bytes PCM extraido do header
reg [31:0] data_read;   // bytes PCM ja consumidos

reg [7:0]  lsb_byte;    // armazena LSB enquanto aguarda MSB
reg        lsb_valid;   // 1 = lsb_byte esta aguardando MSB

// Campos do header (opcionais — uteis para debug/validaçao)
reg [15:0] num_channels;
reg [31:0] sample_rate;
reg [15:0] bits_per_sample;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= ST_HEADER;
        header_cnt      <= 0;
        data_bytes      <= 0;
        data_read       <= 0;
        lsb_valid       <= 0;
        sample_valid    <= 0;
        stream_done     <= 0;
        num_channels    <= 0;
        sample_rate     <= 0;
        bits_per_sample <= 0;
        sample_out      <= 0;
        lsb_byte        <= 0;
    end else begin
        // Pulsos de saida: ativos apenas 1 ciclo
        sample_valid <= 0;
        stream_done  <= 0;

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
                        // Deslocado de 40..43 para 74..77:
                        8'd74: data_bytes[7:0]       <= byte_in;
                        8'd75: data_bytes[15:8]      <= byte_in;
                        8'd76: data_bytes[23:16]     <= byte_in;
                        8'd77: data_bytes[31:24]     <= byte_in;
                        default: ;
                    endcase

                    if (header_cnt == HEADER_SIZE - 1)
                        state <= ST_DATA;
                    else
                        header_cnt <= header_cnt + 1;
                end

                // ----------------------------------------
                // ST_DATA: monta amostras INT16 little-endian
                // byte par   → LSB (bits 7:0 da amostra)
                // byte impar → MSB (bits 15:8 da amostra) → emite
                // ----------------------------------------
                ST_DATA: begin
                    if (!lsb_valid) begin
                        lsb_byte  <= byte_in;
                        lsb_valid <= 1;
                    end else begin
                        sample_out   <= {byte_in, lsb_byte}; // INT16 LE
                        sample_valid <= 1;
                        lsb_valid    <= 0;
                        data_read    <= data_read + 2;

                        if (data_read + 2 >= data_bytes)
                            state <= ST_DONE;
                    end
                end

                // ----------------------------------------
                // ST_DONE: mantem stream_done ativo
                // ----------------------------------------
                ST_DONE: begin
                    stream_done <= 1;
                end

            endcase
        end

        // Mantem stream_done alto apos atingido (mesmo sem byte_valid)
        if (state == ST_DONE)
            stream_done <= 1;
    end
end

endmodule
