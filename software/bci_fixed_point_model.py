import numpy as np
import matplotlib.pyplot as plt

# ==============================================================================
# 1. SYSTEM PARAMETERS & CONSTANTS
# ==============================================================================
FS = 250
DURATION = 6.0
WINDOW_SIZE = 1024
STEP_SIZE = 32

# --- HARDWARE SCALING CONFIGURATION ---
FRACTIONAL_BITS = 12
SCALE_FACTOR = 2 ** FRACTIONAL_BITS  # 4096

# Convert the threshold into fixed-point integer space
ENERGY_THRESHOLD_FLOAT = 35.0
ENERGY_THRESHOLD_FIXED = int(ENERGY_THRESHOLD_FLOAT * SCALE_FACTOR)


# ==============================================================================
# 2. FIXED-POINT SIGNAL GENERATOR & FILE EXPORT
# ==============================================================================
def generate_fixed_point_stimulus():
    t = np.linspace(0, DURATION, int(DURATION * FS), endpoint=False)
    np.random.seed(42)
    noise = np.random.normal(0, 0.5, len(t))

    alpha_wave = 0.4 * np.sin(2 * np.pi * 10 * t)
    mu_wave = 0.5 * np.sin(2 * np.pi * 12 * t)
    mu_wave[(t >= 1.5) & (t <= 4.0)] *= 0.1

    beta_wave = np.zeros(len(t))
    intent_mask = (t >= 1.5) & (t <= 4.0)
    beta_wave[intent_mask] = 1.8 * np.sin(2 * np.pi * 20 * t[intent_mask])

    # 1. Floating point composite baseline signal
    floating_signal = noise + alpha_wave + mu_wave + beta_wave

    # 2. Quantization Math Step: Force decimals into 16-bit Signed Integers
    fixed_signal = np.round(floating_signal * SCALE_FACTOR).astype(np.int16)

    # 3. Export Stimulus to Text File (Acts as your virtual brainwave for SystemVerilog)
    np.savetxt("input_stimulus.txt", fixed_signal, fmt="%d")
    print("SUCCESS: Exported 'input_stimulus.txt' containing 16-bit hardware integers.")

    return t, fixed_signal


# ==============================================================================
# 3. FIXED-POINT MULTI-BAND SPECTRUM ANALYSIS
# ==============================================================================
def run_fixed_point_simulation(t, fixed_signal):
    fft_frequencies = np.fft.rfftfreq(WINDOW_SIZE, d=1 / FS)

    beta_idx = np.where((fft_frequencies >= 14) & (fft_frequencies <= 25))[0]

    window_timestamps = []
    beta_energies_fixed = []
    fsm_power_states = []

    for start_idx in range(0, len(fixed_signal) - WINDOW_SIZE, STEP_SIZE):
        end_idx = start_idx + WINDOW_SIZE
        window_data = fixed_signal[start_idx:end_idx]
        window_timestamps.append(t[start_idx + (WINDOW_SIZE // 2)])

        # Hardware Emulation: FFT handles raw scaled integers
        # We apply bit-shifting inside the math loop to simulate bit-growth control
        fft_output = np.abs(np.fft.rfft(window_data))

        # Calculate Energy in fixed-point space
        beta_energy = np.sum(fft_output[beta_idx] ** 2) / WINDOW_SIZE
        beta_energies_fixed.append(beta_energy)

        # FSM Controller compares integers directly against the scaled threshold
        current_state = 1 if beta_energy > ENERGY_THRESHOLD_FIXED else 0
        fsm_power_states.append(current_state)

    return np.array(window_timestamps), np.array(beta_energies_fixed), np.array(fsm_power_states)


if __name__ == "__main__":
    t, fixed_brain_signal = generate_fixed_point_stimulus()
    win_t, beta_en, power_states = run_fixed_point_simulation(t, fixed_brain_signal)

    # Quick printout verification to confirm threshold matching
    print(f"Fixed Threshold Trigger Level: {ENERGY_THRESHOLD_FIXED}")
    print(f"Peak Detected Fixed Energy: {int(np.max(beta_en))}")
