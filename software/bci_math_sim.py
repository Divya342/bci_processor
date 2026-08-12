import numpy as np
import matplotlib.pyplot as plt

# ==============================================================================
# 1. SYSTEM PARAMETERS & CONSTANTS
# ==============================================================================
FS = 250  # Sampling frequency (250 Hz)
DURATION = 6.0  # Total simulation time in seconds
WINDOW_SIZE = 1024  # Hardware FFT point size (N=128)
STEP_SIZE = 32  # Sliding stride (represents streaming input refresh rate)

ENERGY_THRESHOLD = 35.0  # Mathematical tripwire for FSM state transitions


# ==============================================================================
# 2. SIGNAL GENERATOR (Explicitly Separating Alpha, Mu, and Beta Waves)
# ==============================================================================
def generate_bci_brainwaves():
    t = np.linspace(0, DURATION, int(DURATION * FS), endpoint=False)
    np.random.seed(42)
    noise = np.random.normal(0, 0.5, len(t))

    # Wave 1: Alpha Wave (10 Hz) - Associated with deep relaxation/eyes closed
    alpha_wave = 0.4 * np.sin(2 * np.pi * 10 * t)

    # Wave 2: Mu Wave (12 Hz) - Motor cortex baseline rest rhythm (dies during movement)
    mu_wave = 0.5 * np.sin(2 * np.pi * 12 * t)
    # Suppression effect: Mu wave drops significantly when movement intent begins
    mu_wave[(t >= 1.5) & (t <= 4.0)] *= 0.1

    # Wave 3: Beta Wave (20 Hz) - High energy movement execution intent burst
    beta_wave = np.zeros(len(t))
    intent_mask = (t >= 1.5) & (t <= 4.0)
    beta_wave[intent_mask] = 1.8 * np.sin(2 * np.pi * 20 * t[intent_mask])

    # Combine everything into the single composite voltage wave the electrodes pick up
    raw_signal = noise + alpha_wave + mu_wave + beta_wave
    return t, raw_signal


# ==============================================================================
# 3. CLOSING THE LOOP: MULTI-BAND SPECTRUM ANALYSIS
# ==============================================================================
def run_hardware_simulation(t, raw_signal):
    fft_frequencies = np.fft.rfftfreq(WINDOW_SIZE, d=1 / FS)

    # Map explicit bands to different mathematical indices
    alpha_idx = np.where((fft_frequencies >= 8) & (fft_frequencies <= 11))[0]
    mu_idx = np.where((fft_frequencies >= 11) & (fft_frequencies <= 13))[0]
    beta_idx = np.where((fft_frequencies >= 14) & (fft_frequencies <= 25))[0]  # Target Focus

    window_timestamps = []
    alpha_energies = []
    mu_energies = []
    beta_energies = []
    fsm_power_states = []

    for start_idx in range(0, len(raw_signal) - WINDOW_SIZE, STEP_SIZE):
        end_idx = start_idx + WINDOW_SIZE
        window_data = raw_signal[start_idx:end_idx]
        window_timestamps.append(t[start_idx + (WINDOW_SIZE // 2)])

        # Calculate full spectrum
        fft_output = np.abs(np.fft.rfft(window_data))

        # Extract energy for all bands independently
        alpha_energies.append(np.sum(fft_output[alpha_idx] ** 2) / WINDOW_SIZE)
        mu_energies.append(np.sum(fft_output[mu_idx] ** 2) / WINDOW_SIZE)

        # Beta wave acts as the primary movement trigger
        beta_energy = np.sum(fft_output[beta_idx] ** 2) / WINDOW_SIZE
        beta_energies.append(beta_energy)

        # FSM Controller checks ONLY the Beta Movement band to trigger power rails
        current_state = 1 if beta_energy > ENERGY_THRESHOLD else 0
        fsm_power_states.append(current_state)

    return (np.array(window_timestamps), np.array(alpha_energies),
            np.array(mu_energies), np.array(beta_energies), np.array(fsm_power_states))


# ==============================================================================
# 4. EXECUTION & MULTI-WAVE VISUALIZATION
# ==============================================================================
if __name__ == "__main__":
    t, brain_signal = generate_bci_brainwaves()
    win_t, alpha_en, mu_en, beta_en, power_states = run_hardware_simulation(t, brain_signal)

    plt.figure(figsize=(12, 9))

    # Plot 1: Composite Raw Signal
    plt.subplot(3, 1, 1)
    plt.plot(t, brain_signal, color='darkslategray', alpha=0.7, label="Composite Brainwave Signal (μV)")
    plt.axvspan(1.5, 4.0, color='orange', alpha=0.12, label="Physical Movement Intent Phase")
    plt.title("Advanced BCI ASIC Simulation: Multi-Wave Energy Extraction")
    plt.ylabel("Voltage (μV)")
    plt.legend(loc="upper right")
    plt.grid(True, linestyle='--', alpha=0.5)

    # Plot 2: Independent Frequency Tracker (Showing all 3 states cleanly)
    plt.subplot(3, 1, 2)
    plt.plot(win_t, alpha_en, color='teal', linestyle='--', label="Alpha Band Power (8-11 Hz: Rest)")
    plt.plot(win_t, mu_en, color='purple', linestyle='-.', label="Mu Band Power (11-13 Hz: Motor Rest)")
    plt.plot(win_t, beta_en, color='crimson', linewidth=2, label="Beta Band Power (14-25 Hz: Active Movement)")
    plt.axhline(y=ENERGY_THRESHOLD, color='black', linestyle=':', label="ASIC Logic Threshold")
    plt.ylabel("Calculated Power Spectrum")
    plt.legend(loc="upper right")
    plt.grid(True, linestyle='--', alpha=0.5)

    # Plot 3: FSM Output Command
    plt.subplot(3, 1, 3)
    plt.step(win_t, power_states, where='mid', color='blue', linewidth=2.5, label="FSM Output Control Line")
    plt.ylim(-0.2, 1.2)
    plt.yticks([0, 1], ['0: SLEEP\n(Clock Gated)', '1: ACTIVE\n(Full Hardware On)'])
    plt.xlabel("Time (Seconds)")
    plt.ylabel("Hardware Power Status")
    plt.legend(loc="upper right")
    plt.grid(True, linestyle='--', alpha=0.5)

    plt.tight_layout()
    plt.show()
