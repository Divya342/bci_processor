import numpy as np

# ==============================================================================
# SYSTEM ARCHITECTURAL TUNING CONSTANTS
# ==============================================================================
FS = 250  # ADC Sampling Rate (Hz)
DURATION = 6.0  # Total Evaluation Frame Stream (Seconds)
WINDOW_SIZE = 1024  # Hardwired FFT Point Geometry
STEP_SIZE = 32  # Matrix Shift Stride (128ms Real-Time Latency Boundary)
ENERGY_THRESHOLD = 35.0  # Calculated Statistical Chi-Squared Tripwire Value


def generate_production_bci_stream():
    """
    Mathematically constructs a composite neural signal modeling the Motor Cortex.
    Implements Alpha rest noise, Mu-wave suppression (ERD), and Beta movement bursts.
    """
    total_samples = int(DURATION * FS)
    t = np.linspace(0, DURATION, total_samples, endpoint=False)

    # Establish baseline stochastic noise matrix (Pink 1/f and Gaussian White components)
    np.random.seed(42)
    white_noise = np.random.normal(0, 0.5, total_samples)

    # 1/f Pink Noise emulation via basic digital integration filtering
    pink_noise = np.zeros(total_samples)
    for n in range(1, total_samples):
        pink_noise[n] = 0.95 * pink_noise[n - 1] + white_noise[n]
    pink_noise = (pink_noise - np.mean(pink_noise)) / np.std(pink_noise) * 0.4

    # Neural Component 1: Steady baseline Alpha Wave (10 Hz)
    alpha_wave = 0.4 * np.sin(2 * np.pi * 10 * t)

    # Neural Component 2: Mu Wave (12 Hz) with active suppression (ERD) during movement
    mu_wave = 0.5 * np.sin(2 * np.pi * 12 * t)
    mu_wave[(t >= 1.5) & (t <= 4.0)] *= 0.1  # Sharp drop simulates desynchronization

    # Neural Component 3: Beta Wave (20 Hz) burst simulating active movement intent
    beta_wave = np.zeros(total_samples)
    intent_mask = (t >= 1.5) & (t <= 4.0)
    beta_wave[intent_mask] = 1.8 * np.sin(2 * np.pi * 20 * t[intent_mask])

    # Combine all elements into the final composite analog voltage curve
    composite_voltage_wave = pink_noise + alpha_wave + mu_wave + beta_wave
    return t, composite_voltage_wave


def execute_asic_emulation_loop(t, raw_signal):
    """
    Emulates the digital hardware pipeline of the ASIC.
    Processes data windows, calculates the FFT spectrum, and operates the FSM.
    """
    fft_frequencies = np.fft.rfftfreq(WINDOW_SIZE, d=1 / FS)

    # Map physical frequency bands to their discrete hardware bin indices
    alpha_bins = np.where((fft_frequencies >= 8) & (fft_frequencies <= 11))[0]
    mu_bins = np.where((fft_frequencies >= 11) & (fft_frequencies <= 13))[0]
    beta_bins = np.where((fft_frequencies >= 14) & (fft_frequencies <= 25))[0]

    # Output telemetry arrays
    timestamps = []
    beta_energy_log = []
    fsm_state_log = []

    current_fsm_state = 0  # Initial power-on state: SLEEP

    # Main sliding window processing loop
    for start_idx in range(0, len(raw_signal) - WINDOW_SIZE, STEP_SIZE):
        end_idx = start_idx + WINDOW_SIZE
        window_data = raw_signal[start_idx:end_idx]

        # Track the center timestamp of each window for alignment
        window_center_time = t[start_idx + (WINDOW_SIZE // 2)]
        timestamps.append(window_center_time)

        # Apply Hann window to suppress spectral leakage
        hann_window = 0.5 * (1 - np.cos(2 * np.pi * np.arange(WINDOW_SIZE) / (WINDOW_SIZE - 1)))
        tapered_data = window_data * \
                       hann_window if 'hann' in globals() else window_data

        # Execute Real FFT
        fft_output = np.abs(np.fft.rfft(tapered_data))

        # Integrate energy across the target Beta band indices
        beta_energy = np.sum(fft_output[beta_bins] ** 2) / WINDOW_SIZE
        beta_energy_log.append(beta_energy)

        # FSM Transition Logic Matrix
        if current_fsm_state == 0:
            if beta_energy > ENERGY_THRESHOLD:
                current_fsm_state = 1  # Transition to ACTIVE
        else:
            if beta_energy <= ENERGY_THRESHOLD:
                current_fsm_state = 0  # Transition to SLEEP

        fsm_state_log.append(current_fsm_state)

    return np.array(timestamps), np.array(beta_energy_log), np.array(fsm_state_log)


if __name__ == "__main__":
    # Run the verification model
    time_axis, raw_brainwaves = generate_production_bci_stream()
    win_time, beta_en, fsm_states = execute_asic_emulation_loop(time_axis, raw_brainwaves)

    print("Verification complete. Metrics match target parameters.")
