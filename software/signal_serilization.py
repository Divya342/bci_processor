import numpy as np


# Use your existing signal data and power track arrays from your PyCharm execution
# Assumes 't', 'fixed_brain_signal', and 'power_states' have been computed by your loop

def serialize_simulation_vectors(t, fixed_signal, fsm_power_states):
    """
    Executes Step 2: Signal Serialization.
    Converts internal Python simulation arrays into formatted hardware text vectors.
    """
    print("\nExecuting Step 2: Signal Serialization Pipeline...")

    # 1. Export Raw Input Stimulus (The virtual brainwave stream for the ASIC input pins)
    # Saved as raw decimal integers to match standard $readmemh/$readmemb hardware tasks
    np.savetxt("input_stimulus.txt", fixed_signal, fmt="%d")
    print(" -> SUCCESS: Generated 'input_stimulus.txt' [Contains raw input voltage integers]")

    # 2. Export Expected FSM Golden Outputs (Used for automated hardware testbench verification)
    # Since the FSM state changes per window step size, we match it to its center timestamp
    fsm_output_data = np.column_stack((t[::32][:len(fsm_power_states)], fsm_power_states))
    np.savetxt("expected_fsm_output.txt", fsm_output_data, fmt="%.4f %d")
    print(" -> SUCCESS: Generated 'expected_fsm_output.txt' [Contains timestamped target states]")

    # 3. Structural Integrity Check: Print verification block samples
    print("\n--- STIMULUS MATRIX PORTION EXAMPLES ---")
    print(f"First 10 Data Points entering Hardware Stream: {fixed_signal[:10]}")
    print(f"Target FSM State Sequence across first 5 evaluation frames: {fsm_power_states[:5]}")
    print("-" * 40)

# Run the serialization function below your main simulation loop execution
# serialize_simulation_vectors(t, fixed_brain_signal, power_states)
