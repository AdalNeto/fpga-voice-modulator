# Modulador de voz baseado em FPGA com efeitos de alteração de tom

Este repositório contém a implementação de um sistema embarcado de processamento digital de sinais (PDS) para modulação de voz desenvolvido como projeto da disciplina Laboratório Integrado III-A.

O sistema lê arquivos de áudio `.wav` de um cartão SD, processa os dados em hardware dedicado e reproduz o som modificado através do codec de áudio da placa.

## FPGA SDcard File Reader
Créditos: https://github.com/WangXuan95/FPGA-SDcard-Reader

## Pinos FPGA

| Sinal | Pino DE2-115 | Direção |
| --- | --- | --- |
| SD_CLK | PIN_AE13 | output |
| SD_CMD | PIN_AD14 | inout |
| SD_DAT0 | PIN_AE14 | input |
| CLOCK_50 | PIN_Y2 | input |
| KEY0 | PIN_M23 | input |
| LEDR[0..3] | PIN_G19, F19, E19, F21 | output |
| HEX0[0..6] | Verificar manual | output |
| HEX1[0..6] | Verificar manual | output |
