`timescale 1ns / 1ps

module wm8731_config (
    input  wire clk,         // CLOCK_50 (50 MHz)
    input  wire rst_n,       // Reset ativo-baixo (KEY0)
    output reg  i2c_sclk,    // Clock I2C (PIN_B7)
    inout  wire i2c_sdat,    // Dados I2C open-drain (PIN_A8)
    output reg  config_done  // 1 quando todos os registradores forem gravados
);

    reg [11:0] clk_div;
    wire tick = (clk_div == 12'd2499);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)    clk_div <= 12'd0;
        else if (tick) clk_div <= 12'd0;
        else           clk_div <= clk_div + 1'b1;
    end

    reg [23:0] rom [0:10];
    initial begin
        rom[0]  = 24'h34_1E_00; // R15: Reset do codec
        rom[1]  = 24'h34_00_97; // R0:  Left Line In
        rom[2]  = 24'h34_02_97; // R1:  Right Line In
        rom[3]  = 24'h34_05_79; // R2:  Left Headphone Out (0 dB)
        rom[4]  = 24'h34_07_79; // R3:  Right Headphone Out (0 dB)
        rom[5]  = 24'h34_08_12; // R4:  Analogue Audio Path (DAC selecionado)
        rom[6]  = 24'h34_0A_00; // R5:  Digital Audio Path (Unmute)
        rom[7]  = 24'h34_0C_00; // R6:  Power Down Control (Tudo ligado)
        rom[8]  = 24'h34_0E_02; // R7:  Digital Audio Interface (I2S, 16-bit)
        rom[9]  = 24'h34_10_00; // R8:  Sampling Control (Normal, 256fs)
        rom[10] = 24'h34_12_01; // R9:  Active Control (Ativa DAC/I2S)
    end

    reg [5:0]  bit_idx;
    reg [3:0]  cmd_idx;
    reg [23:0] shift_reg;
    reg        sdat_out;
    reg [2:0]  state;

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_CLK_L = 3'd2;
    localparam S_CLK_H = 3'd3;
    localparam S_STOP1 = 3'd4;
    localparam S_STOP2 = 3'd5;
    localparam S_STOP3 = 3'd6;
    localparam S_DONE  = 3'd7;

    assign i2c_sdat = sdat_out ? 1'bz : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            i2c_sclk    <= 1'b1;
            sdat_out    <= 1'b1;
            cmd_idx     <= 4'd0;
            bit_idx     <= 6'd0;
            shift_reg   <= 24'd0;
            config_done <= 1'b0;
        end else if (tick) begin
            case (state)
                S_IDLE: begin
                    i2c_sclk <= 1'b1;
                    sdat_out <= 1'b1;
                    if (cmd_idx < 4'd11) begin
                        shift_reg <= rom[cmd_idx];
                        bit_idx   <= 6'd0;
                        state     <= S_START;
                    end else begin
                        config_done <= 1'b1;
                        state       <= S_DONE;
                    end
                end

                S_START: begin
                    sdat_out <= 1'b0;
                    state    <= S_CLK_L;
                end

                S_CLK_L: begin
                    i2c_sclk <= 1'b0;
                    if (bit_idx == 8 || bit_idx == 17 || bit_idx == 26) begin
                        sdat_out <= 1'b1;
                    end else begin
                        sdat_out  <= shift_reg[23];
                        shift_reg <= {shift_reg[22:0], 1'b0};
                    end
                    state <= S_CLK_H;
                end

                S_CLK_H: begin
                    i2c_sclk <= 1'b1;
                    if (bit_idx == 6'd26) begin
                        state <= S_STOP1;
                    end else begin
                        bit_idx <= bit_idx + 1'b1;
                        state   <= S_CLK_L;
                    end
                end

                S_STOP1: begin
                    i2c_sclk <= 1'b0;
                    sdat_out <= 1'b0;
                    state    <= S_STOP2;
                end

                S_STOP2: begin
                    i2c_sclk <= 1'b1; // Sobe SCL primeiro
                    sdat_out <= 1'b0;
                    state    <= S_STOP3;
                end

                S_STOP3: begin
                    i2c_sclk <= 1'b1; // Sobe SDA depois de SCL (STOP válido)
                    sdat_out <= 1'b1;
                    cmd_idx  <= cmd_idx + 1'b1;
                    state    <= S_IDLE;
                end

                S_DONE: begin
                    config_done <= 1'b1;
                    i2c_sclk    <= 1'b1;
                    sdat_out    <= 1'b1;
                end
            endcase
        end
    end

endmodule