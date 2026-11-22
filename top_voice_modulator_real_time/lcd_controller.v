// ==============================================================================
// Módulo   : lcd_controller.v
// Projeto  : Modulador de Voz em FPGA (ENGG54 - UFBA)
// Função   : Controle do display LCD 16x2 (HD44780) da DE2-115 com atualização
//            contínua do modo (SW[1:0]), fonte (SD/Microfone) e status/erros
// Padrão   : Verilog-2001 (IEEE 1364-2001)
// ==============================================================================

`timescale 1ns / 1ps

module lcd_controller (
    input  wire       clk,            // Clock do sistema (50 MHz)
    input  wire       rst_n,          // Reset ativo baixo
    input  wire [1:0] sw,             // 00/01: Natural, 10: Hélio, 11: Vader
    input  wire       mic_mode,       // 0 = Cartão SD, 1 = Microfone ao vivo
    input  wire       file_found,     // 1 = arquivo .wav localizado no SD
    input  wire       file_not_found, // 1 = timeout de busca (arquivo ausente)
    input  wire       finished,       // 1 = reprodução concluída (aguardando KEY1)

    output reg  [7:0] LCD_DATA,       // Barramento de dados de 8 bits
    output wire       LCD_RW,         // 0 = Escrita, 1 = Leitura
    output reg        LCD_EN,         // Pulso de Enable do controlador HD44780
    output reg        LCD_RS,         // 0 = Comando, 1 = Dado (caractere ASCII)
    output wire       LCD_ON,         // Alimentação lógica do módulo LCD
    output wire       LCD_BLON        // Backlight (não suportado pelo hardware DE2-115)
);

    // --------------------------------------------------------------------------
    // 1. Sinais Fixos de Controle do LCD
    // --------------------------------------------------------------------------
    assign LCD_ON   = 1'b1; // Mantém o controlador HD44780 energizado
    assign LCD_RW   = 1'b0; // Operação exclusiva de escrita
    assign LCD_BLON = 1'b0; // Pino sem função física no LCD reflexivo da DE2-115

    // --------------------------------------------------------------------------
    // 2. Seleção Dinâmica das Mensagens das Linhas 1 e 2 (16 caracteres cada)
    // --------------------------------------------------------------------------
    reg [127:0] line1_str;
    reg [127:0] line2_str;

    always @(*) begin
        if (mic_mode) begin
            // Modo Microfone ao Vivo (SW[2] = 1): ignora alertas do cartão SD
            case (sw)
                2'b10:   line1_str = "MODO: HELIO     ";
                2'b11:   line1_str = "MODO: VADER     ";
                default: line1_str = "MODO: NATURAL   ";
            endcase
            line2_str = "MICROFONE VIVO  ";
        end else if (file_not_found) begin
            // Prioridade máxima no modo SD: alerta quando o .wav não é localizado
            line1_str = "ARQUIVO NAO     ";
            line2_str = "ENCONTRADO!     ";
        end else begin
            // Linha 1: exibe o efeito selecionado nas chaves SW[1:0]
            case (sw)
                2'b10:   line1_str = "MODO: HELIO     ";
                2'b11:   line1_str = "MODO: VADER     ";
                default: line1_str = "MODO: NATURAL   ";
            endcase

            // Linha 2: status da busca, reprodução ou espera por KEY1
            if (!file_found)
                line2_str = "BUSCANDO WAV... ";
            else if (finished)
                line2_str = "FIM - KEY1: PLAY";
            else
                line2_str = "TOCANDO AUDIO...";
        end
    end

    // --------------------------------------------------------------------------
    // 3. Estados da Máquina de Estados (FSM)
    // --------------------------------------------------------------------------
    localparam [3:0]
        S_PWR_WAIT     = 4'd0,  // Aguarda estabilização de energia (20 ms)
        S_INIT_1       = 4'd1,  // Sequência de inicialização HD44780 (passo 1)
        S_INIT_2       = 4'd2,  // Sequência de inicialização HD44780 (passo 2)
        S_INIT_3       = 4'd3,  // Sequência de inicialização HD44780 (passo 3)
        S_FUNC_SET     = 4'd4,  // Configura interface 8 bits, 2 linhas, matriz 5x8
        S_DISP_ON      = 4'd5,  // Liga o display e desliga o cursor piscante
        S_ENTRY_MODE   = 4'd6,  // Configura auto-incremento de endereço DDRAM
        S_CLR_DISP     = 4'd7,  // Limpa a tela na inicialização
        S_LINE1_ADDR   = 4'd8,  // Posiciona cursor no início da Linha 1 (0x80)
        S_LINE1_CHAR   = 4'd9,  // Escreve os 16 caracteres da Linha 1
        S_LINE2_ADDR   = 4'd10, // Posiciona cursor no início da Linha 2 (0xC0)
        S_LINE2_CHAR   = 4'd11, // Escreve os 16 caracteres da Linha 2
        S_REFRESH_WAIT = 4'd12, // Intervalo de 10 ms entre atualizações de tela
        S_PULSE_EN     = 4'd13, // Gera pulso de Enable (> 1 us)
        S_HOLD_WAIT    = 4'd14; // Aguarda tempo de execução do comando no HD44780

    reg [3:0]  state;
    reg [3:0]  next_after_wait;
    reg [19:0] delay_cnt;
    reg [19:0] delay_target;
    reg [3:0]  char_idx;

    // --------------------------------------------------------------------------
    // 4. Tarefa Auxiliar para Envio de Comando ou Caractere
    // --------------------------------------------------------------------------
    task send_byte;
        input        is_data;         // 0 = comando, 1 = caractere ASCII
        input [7:0]  byte_val;        // byte a ser colocado em LCD_DATA
        input [19:0] wait_cycles;     // tempo de espera após pulso EN (@ 50 MHz)
        input [3:0]  following_state; // próximo estado após a espera
        begin
            LCD_RS          <= is_data;
            LCD_DATA        <= byte_val;
            LCD_EN          <= 1'b0;
            delay_cnt       <= 20'd0;
            delay_target    <= wait_cycles;
            next_after_wait <= following_state;
            state           <= S_PULSE_EN;
        end
    endtask

    // --------------------------------------------------------------------------
    // 5. Máquina de Estados Principal
    // --------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_PWR_WAIT;
            next_after_wait <= S_INIT_1;
            delay_cnt       <= 20'd0;
            delay_target    <= 20'd0;
            char_idx        <= 4'd0;
            LCD_DATA        <= 8'h00;
            LCD_EN          <= 1'b0;
            LCD_RS          <= 1'b0;
        end else begin
            case (state)
                // Espera inicial de 20 ms após reset/energização
                S_PWR_WAIT: begin
                    if (delay_cnt == 20'd1_000_000) begin
                        delay_cnt <= 20'd0;
                        state     <= S_INIT_1;
                    end else begin
                        delay_cnt <= delay_cnt + 20'd1;
                    end
                end

                // Sequência padrão de inicialização do controlador HD44780
                S_INIT_1:     send_byte(1'b0, 8'h38, 20'd250_000, S_INIT_2);     // 5 ms
                S_INIT_2:     send_byte(1'b0, 8'h38, 20'd10_000,  S_INIT_3);     // 200 us
                S_INIT_3:     send_byte(1'b0, 8'h38, 20'd5_000,   S_FUNC_SET);   // 100 us
                S_FUNC_SET:   send_byte(1'b0, 8'h38, 20'd5_000,   S_DISP_ON);    // 8-bit, 2 linhas
                S_DISP_ON:    send_byte(1'b0, 8'h0C, 20'd5_000,   S_ENTRY_MODE); // Display ON, cursor OFF
                S_ENTRY_MODE: send_byte(1'b0, 8'h06, 20'd5_000,   S_CLR_DISP);   // Auto-incremento
                S_CLR_DISP:   send_byte(1'b0, 8'h01, 20'd100_000, S_LINE1_ADDR); // Clear Display (2 ms)

                // Posiciona cursor na Linha 1, Coluna 0 (endereço DDRAM 0x80)
                S_LINE1_ADDR: begin
                    char_idx <= 4'd0;
                    send_byte(1'b0, 8'h80, 20'd3_000, S_LINE1_CHAR);
                end

                // Envia os 16 caracteres da Linha 1
                S_LINE1_CHAR: begin
                    if (char_idx == 4'd15)
                        send_byte(1'b1, line1_str[127 - char_idx*8 -: 8], 20'd3_000, S_LINE2_ADDR);
                    else begin
                        send_byte(1'b1, line1_str[127 - char_idx*8 -: 8], 20'd3_000, S_LINE1_CHAR);
                        char_idx <= char_idx + 4'd1;
                    end
                end

                // Posiciona cursor na Linha 2, Coluna 0 (endereço DDRAM 0xC0)
                S_LINE2_ADDR: begin
                    char_idx <= 4'd0;
                    send_byte(1'b0, 8'hC0, 20'd3_000, S_LINE2_CHAR);
                end

                // Envia os 16 caracteres da Linha 2
                S_LINE2_CHAR: begin
                    if (char_idx == 4'd15)
                        send_byte(1'b1, line2_str[127 - char_idx*8 -: 8], 20'd3_000, S_REFRESH_WAIT);
                    else begin
                        send_byte(1'b1, line2_str[127 - char_idx*8 -: 8], 20'd3_000, S_LINE2_CHAR);
                        char_idx <= char_idx + 4'd1;
                    end
                end

                // Aguarda 10 ms e reescreve as linhas sem limpar a tela (evita piscar)
                S_REFRESH_WAIT: begin
                    if (delay_cnt == 20'd500_000) begin
                        delay_cnt <= 20'd0;
                        state     <= S_LINE1_ADDR;
                    end else begin
                        delay_cnt <= delay_cnt + 20'd1;
                    end
                end

                // Gera pulso de Enable com setup/hold garantidos (> 1,4 us)
                S_PULSE_EN: begin
                    if (delay_cnt == 20'd50)
                        LCD_EN <= 1'b1;

                    if (delay_cnt == 20'd120) begin
                        LCD_EN    <= 1'b0;
                        delay_cnt <= 20'd0;
                        state     <= S_HOLD_WAIT;
                    end else begin
                        delay_cnt <= delay_cnt + 20'd1;
                    end
                end

                // Aguarda o tempo necessário para o HD44780 processar o byte
                S_HOLD_WAIT: begin
                    if (delay_cnt >= delay_target) begin
                        delay_cnt <= 20'd0;
                        state     <= next_after_wait;
                    end else begin
                        delay_cnt <= delay_cnt + 20'd1;
                    end
                end

                default: state <= S_PWR_WAIT;
            endcase
        end
    end

endmodule