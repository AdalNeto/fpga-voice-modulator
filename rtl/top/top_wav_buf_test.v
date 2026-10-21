// top_wav_buf_test.v
// Teste em placa: SD -> sd_file_reader -> wav_reader -> wav_buffer -> "consumidor falso" a 44,1 kHz
// (o consumidor falso faz o papel do I2S: puxa 1 amostra a cada ~22,7 us).
//
// LEDR[0] = SD inicializado          LEDR[1] = arquivo encontrado
// LEDR[2] = ERRO (overrun ou underrun do buffer, pegajoso)   -> deve ficar APAGADO
// LEDR[3] = arquivo inteiro consumido (finished)
// HEX1:HEX0 = contador de amostras consumidas (8 bits baixos)
// Esperado ao final: contador = (tamanho do arquivo - 44) / 2   (mod 256)
module top_wav_buf_test #(
    parameter            FILE_NAME_LEN = 9,
    parameter [52*8-1:0] FILE_NAME     = "voice.wav"
)(
    input  wire        CLOCK_50,
    input  wire        KEY0,
    output wire        SD_CLK,
    inout  wire        SD_CMD,
    input  wire        SD_DAT0,
    output wire [3:0]  LEDR,
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1
);
wire rst_n = KEY0;

wire [3:0] card_stat; wire [1:0] card_type, fs_type;
wire file_found, outen; wire [7:0] outbyte;
wire can_read;

sd_file_reader #(.FILE_NAME_LEN(FILE_NAME_LEN), .FILE_NAME(FILE_NAME), .CLK_DIV(3'd2), .SIMULATE(0)) u_sd (
    .rstn(rst_n), .clk(CLOCK_50),
    .can_read(can_read),                         // <-- controle de fluxo vindo do wav_buffer
    .sdclk(SD_CLK), .sdcmd(SD_CMD), .sddat0(SD_DAT0),
    .card_stat(card_stat), .card_type(card_type), .filesystem_type(fs_type),
    .file_found(file_found), .outen(outen), .outbyte(outbyte));

wire [15:0] sample_out; wire sample_valid, stream_done;
wav_reader u_wav (.clk(CLOCK_50), .rst_n(rst_n), .byte_in(outbyte), .byte_valid(outen),
                  .sample_out(sample_out), .sample_valid(sample_valid), .stream_done(stream_done));

// ---- consumidor falso: 50 MHz / 1134 = 44,09 kHz ----
reg  [10:0] div;
reg         rd_en;
wire        playable, finished, overrun, underrun, rd_valid;
wire [15:0] rd_data;
wire [10:0] level;

always @(posedge CLOCK_50 or negedge rst_n)
    if (!rst_n) begin div <= 0; rd_en <= 0; end
    else begin
        rd_en <= 0;
        if (div == 11'd1133) begin div <= 0; rd_en <= playable && !finished; end
        else div <= div + 1'b1;
    end

wav_buffer #(.ADDR_W(10), .SECTOR_SAMPLES(256), .PRIME_SAMPLES(256)) u_buf (
    .clk(CLOCK_50), .rst_n(rst_n),
    .wr_data(sample_out), .wr_en(sample_valid), .eos(stream_done),
    .can_read(can_read),
    .rd_en(rd_en), .rd_data(rd_data), .rd_valid(rd_valid),
    .playable(playable), .finished(finished), .level(level),
    .overrun(overrun), .underrun(underrun));

reg [31:0] consumed;
always @(posedge CLOCK_50 or negedge rst_n)
    if (!rst_n) consumed <= 0;
    else if (rd_valid) consumed <= consumed + 1;

assign LEDR[0] = (card_stat >= 4'd8);
assign LEDR[1] = file_found;
assign LEDR[2] = overrun | underrun;
assign LEDR[3] = finished;

function [6:0] seg7; input [3:0] d; begin
    case (d)
        4'h0: seg7 = 7'b1000000; 4'h1: seg7 = 7'b1111001; 4'h2: seg7 = 7'b0100100; 4'h3: seg7 = 7'b0110000;
        4'h4: seg7 = 7'b0011001; 4'h5: seg7 = 7'b0010010; 4'h6: seg7 = 7'b0000010; 4'h7: seg7 = 7'b1111000;
        4'h8: seg7 = 7'b0000000; 4'h9: seg7 = 7'b0010000; 4'hA: seg7 = 7'b0001000; 4'hB: seg7 = 7'b0000011;
        4'hC: seg7 = 7'b1000110; 4'hD: seg7 = 7'b0100001; 4'hE: seg7 = 7'b0000110; 4'hF: seg7 = 7'b0001110;
        default: seg7 = 7'b1111111;
    endcase end endfunction
assign HEX0 = seg7(consumed[3:0]);
assign HEX1 = seg7(consumed[7:4]);
endmodule
