// top_wav_sd.v
// Top-level para teste de leitura WAV via SD card na DE2-115
//
// Hierarquia:
//   top_wav_sd
//   └── sd_file_reader   (sd_file_reader.v)
//       └── sd_reader    (sd_reader.v)
//           └── sdcmd_ctrl (sdcmd_ctrl.v)
//   └── wav_reader       (wav_reader.v)
//
// ANTES DE SINTETIZAR:
//   Alterar FILE_NAME e FILE_NAME_LEN para o nome do seu arquivo WAV.
//   Exemplo: "voice.wav" tem 9 caracteres -> FILE_NAME_LEN = 9
//   O nome eh case-insensitive (sd_file_reader converte para maiusculo).
//
// VERIFICAÇAO via LEDs:
//   LEDR[0] = SD inicializado (card_stat chegou ao estado CMD17 = 4'd8)
//   LEDR[1] = arquivo WAV encontrado no cartao
//   LEDR[2] = toggle a cada amostra recebida (pisca durante leitura)
//   LEDR[3] = leitura completa (stream_done)
//
// VERIFICAÇAO via HEX:
//   HEX3:HEX0 = 16 bits menos significativos do contador de amostras (amostras[15:0])
//   Exemplo: para um WAV de 44100 Hz / 1 segundo -> 44100 = 0xAC44 (HEX3..0 = AC44)

module top_wav_sd #(
    // -------------------------------------------------------
    // ALTERE AQUI: nome do arquivo WAV no cartao SD
    // O arquivo deve estar na raiz do cartao (formatado em FAT32)
    // -------------------------------------------------------
    parameter            FILE_NAME_LEN = 9,
    parameter [52*8-1:0] FILE_NAME     = "voice.wav"
)(
    input  wire        CLOCK_50,
    input  wire        KEY0,        // Reset ativo-baixo (botao na DE2-115)

    // SD Card — SD mode (nao SPI)
    output wire        SD_CLK,
    inout  wire        SD_CMD,
    input  wire        SD_DAT0,

    // LEDs de status (LEDR[3:0] na DE2-115)
    output wire [3:0]  LEDR,

    // Displays 7-segmentos (HEX0 a HEX3, common-anode, ativo-baixo)
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3
);

// -------------------------------------------------------
// Reset
// KEY0 na DE2-115 eh ativo-baixo (0 = pressionado = reset)
// -------------------------------------------------------
wire rst_n = KEY0;

// -------------------------------------------------------
// Sinais internos: sd_file_reader -> wav_reader
// -------------------------------------------------------
wire [3:0] card_stat;      // estado interno do sd_reader (4'd8 = pronto)
wire [1:0] card_type;      // tipo do cartao (2=SDv2, 3=SDHCv2)
wire [1:0] fs_type;        // filesystem (2=FAT16, 3=FAT32)
wire       file_found;     // 1 quando o arquivo WAV foi localizado
wire       outen;          // pulso: byte do arquivo disponivel
wire [7:0] outbyte;        // byte do conteudo do arquivo

// -------------------------------------------------------
// sd_file_reader
// CLK_DIV=3'd2 para clk entre 25~50 MHz (CLOCK_50 = 50 MHz)
// -------------------------------------------------------
sd_file_reader #(
    .FILE_NAME_LEN ( FILE_NAME_LEN ),
    .FILE_NAME     ( FILE_NAME     ),
    .CLK_DIV       ( 3'd2          ),
    .SIMULATE      ( 0             )
) u_sd_reader (
    .rstn            ( rst_n      ),
    .clk             ( CLOCK_50   ),
    .sdclk           ( SD_CLK     ),
    .sdcmd           ( SD_CMD     ),
    .sddat0          ( SD_DAT0    ),
    .card_stat       ( card_stat  ),
    .card_type       ( card_type  ),
    .filesystem_type ( fs_type    ),
    .file_found      ( file_found ),
    .outen           ( outen      ),
    .outbyte         ( outbyte    )
);

// -------------------------------------------------------
// wav_reader
// Recebe o stream de bytes e extrai amostras INT16
// -------------------------------------------------------
wire [15:0] sample_out;
wire        sample_valid;
wire        stream_done;

wav_reader u_wav_reader (
    .clk          ( CLOCK_50     ),
    .rst_n        ( rst_n        ),
    .byte_in      ( outbyte      ),
    .byte_valid   ( outen        ),
    .sample_out   ( sample_out   ),
    .sample_valid ( sample_valid ),
    .stream_done  ( stream_done  )
);

// -------------------------------------------------------
// Contador de amostras (32 bits)
// -------------------------------------------------------
reg [31:0] sample_count;

always @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n)
        sample_count <= 32'd0;
    else if (sample_valid)
        sample_count <= sample_count + 1'b1;
end

// -------------------------------------------------------
// Toggle de LED: pisca durante a extracao das amostras
// -------------------------------------------------------
reg led_toggle;
always @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n)
        led_toggle <= 1'b0;
    else if (sample_valid)
        led_toggle <= ~led_toggle;
end

// -------------------------------------------------------
// Mapeamento dos LEDs
// -------------------------------------------------------
assign LEDR[0] = (card_stat >= 4'd8); // SD pronto (CMD17)
assign LEDR[1] = file_found;           // voice.wav encontrado
assign LEDR[2] = led_toggle;           // pisca durante leitura
assign LEDR[3] = stream_done;          // leitura concluida

// -------------------------------------------------------
// Display HEX: mostra os 16 bits baixos do sample_count
// HEX0 = bits [3:0]
// HEX1 = bits [7:4]
// HEX2 = bits [11:8]
// HEX3 = bits [15:12]
// -------------------------------------------------------
function [6:0] seg7;
    input [3:0] d;
    case (d)
        4'h0: seg7 = 7'b1000000;
        4'h1: seg7 = 7'b1111001;
        4'h2: seg7 = 7'b0100100;
        4'h3: seg7 = 7'b0110000;
        4'h4: seg7 = 7'b0011001;
        4'h5: seg7 = 7'b0010010;
        4'h6: seg7 = 7'b0000010;
        4'h7: seg7 = 7'b1111000;
        4'h8: seg7 = 7'b0000000;
        4'h9: seg7 = 7'b0010000;
        4'hA: seg7 = 7'b0001000;
        4'hB: seg7 = 7'b0000011;
        4'hC: seg7 = 7'b1000110;
        4'hD: seg7 = 7'b0100001;
        4'hE: seg7 = 7'b0000110;
        4'hF: seg7 = 7'b0001110;
        default: seg7 = 7'b1111111;
    endcase
endfunction

assign HEX0 = seg7(sample_count[3:0]);
assign HEX1 = seg7(sample_count[7:4]);
assign HEX2 = seg7(sample_count[11:8]);
assign HEX3 = seg7(sample_count[15:12]);

endmodule