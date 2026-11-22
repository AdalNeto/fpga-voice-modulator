`timescale 1ns / 1ps

module audio_pll (
    input  wire inclk0, // 50 MHz (CLOCK_50)
    output wire c0,     // 11,2903 MHz -> fs = 44,10 kHz (Voz Natural)
    output wire c1,     // 20,5882 MHz -> fs = 80,42 kHz (Modo Hélio - 1,82x)
    output wire c2,     // 10,0000 MHz -> fs = 39,06 kHz (Modo Vader - 0,89x)
    output wire locked
);

    wire [4:0] sub_wire0;
    wire       sub_wire1;
    wire [1:0] sub_wire2 = {1'b0, inclk0};

    assign c0     = sub_wire0[0];
    assign c1     = sub_wire0[1];
    assign c2     = sub_wire0[2];
    assign locked = sub_wire1;

    altpll #(
        .bandwidth_type          ("AUTO"),
        .clk0_divide_by          (31),
        .clk0_duty_cycle         (50),
        .clk0_multiply_by        (7),
        .clk0_phase_shift        ("0"),
        .clk1_divide_by          (17),
        .clk1_duty_cycle         (50),
        .clk1_multiply_by        (7),
        .clk1_phase_shift        ("0"),
        .clk2_divide_by          (5),
        .clk2_duty_cycle         (50),
        .clk2_multiply_by        (1),
        .clk2_phase_shift        ("0"),
        .compensate_clock        ("CLK0"),
        .inclk0_input_frequency  (20000),
        .intended_device_family  ("Cyclone IV E"),
        .lpm_type                ("altpll"),
        .operation_mode          ("NORMAL"),
        .pll_type                ("AUTO"),
        .port_clk0               ("PORT_USED"),
        .port_clk1               ("PORT_USED"),
        .port_clk2               ("PORT_USED"),
        .port_clk3               ("PORT_UNUSED"),
        .port_clk4               ("PORT_UNUSED"),
        .port_clk5               ("PORT_UNUSED"),
        .port_inclk0             ("PORT_USED"),
        .port_inclk1             ("PORT_UNUSED"),
        .port_locked             ("PORT_USED"),
        .port_areset             ("PORT_UNUSED"),
        .port_pfdena             ("PORT_UNUSED"),
        .port_phasecounterselect ("PORT_UNUSED"),
        .port_scanclk            ("PORT_UNUSED"),
        .port_scanclkena         ("PORT_UNUSED"),
        .port_scandata           ("PORT_UNUSED"),
        .port_scandataout        ("PORT_UNUSED"),
        .port_scandone           ("PORT_UNUSED"),
        .width_clock             (5)
    ) altpll_component (
        .inclk  (sub_wire2),
        .clk    (sub_wire0),
        .locked (sub_wire1)
    );

endmodule