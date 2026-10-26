import numpy as np
from pathlib import Path

# Obtém a pasta onde este script está (d:/fpga-voice-modulator/python)
script_dir = Path(__file__).resolve().parent

# Define o caminho de saída exato: d:/fpga-voice-modulator/rtl/rom/tanh_lut.hex
output_file = script_dir.parent / "rtl" / "rom" / "tanh_lut.hex"

# Garante que a pasta rtl/rom/ exista
output_file.parent.mkdir(parents=True, exist_ok=True)

N_ENTRIES = 256
values = []

for i in range(N_ENTRIES):
    # x varia de 0.0 a 1.0 em 256 passos
    x = i / (N_ENTRIES - 1)
    # Equação do projeto: y = 0.6 * tanh(2 * x)
    y = 0.6 * np.tanh(2.0 * x)
    # Converte para ponto fixo Q15 com saturação (32768 = 1.0)
    q15_val = int(np.round(y * 32768.0))
    q15_val = min(32767, max(0, q15_val))
    values.append(q15_val)

# Grava no formato HEX compatível com $readmemh
with open(output_file, "w") as f:
    for val in values:
        f.write(f"{val:04X}\n")

print(f"[OK] Arquivo gerado com sucesso em:\n -> {output_file}")