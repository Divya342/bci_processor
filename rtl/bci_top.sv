`timescale 1ns / 1ps

module bci_top (
    input  logic              clk,             // Master System Clock Pin (15.7 MHz)
    input  logic              rst_n,           // Asynchronous Active-Low Reset Pin

    // --- BIOLOGICAL ELECTRODE INTERFACE ---
    input  logic              data_valid_i,    // Valid input strobe from electrode converter
    input  logic signed [15:0] data_in_i,       // 16-bit Signed Q3.12 incoming brainwave voltage

    // --- MASTER RAIL TELEMETRY OUTPUTS ---
    output logic              hw_wake_o        // Global Status Output: 0=Sleep, 1=Active
);

    // Import global constants for structural vector wiring consistency
    import bci_config_pkg::*;

    // ==========================================================================
    // INTERNAL STRUCTURAL INTERCONNECT WIRES (ASIC Data & Control Buses)
    // ==========================================================================
    // Block 4 Control Signals
    logic        icg_gate_en;                  // Clock-gating control line from FSM to ICG cells

    // Block 1 to Block 2 Interface
    logic        window_valid;                 // Handshake: Data package is steady
    logic        fft_ready;                    // Handshake: FFT engine is clear to load
    logic [15:0] window_data_stream;           // Serialized window data transfer bus

    // Block 2 to Block 3 Interface
    logic        fft_valid;                    // Strobe high indicating transform array is stable
    logic [15:0] fft_real_bus [0:64];          // Parallel 65-Bin Real data highways
    logic [15:0] fft_imag_bus [0:64];          // Parallel 65-Bin Imaginary data highways

    // Block 3 to Block 4 Interface
    logic        energy_valid;                 // Strobe high indicating MAC accumulation is complete
    logic [31:0] beta_energy_bus;              // 32-bit Unsigned Integer Energy Bus

    // ==========================================================================
    // INSTANTIATION 1: BLOCK 1 - INPUT MEMORY BANK WINDOW BUFFER
    // ==========================================================================
    bci_window_buffer u_window_buffer (
        .clk             (clk),
        .rst_n           (rst_n),
        // Electrode Inputs
        .data_valid_i    (data_valid_i),
        .data_in_i       (data_in_i),
        // Downstream FFT Handshake Wire Ports
        .fft_ready_i     (fft_ready),
        .window_valid_o  (window_valid),
        .window_data_o   (window_data_stream)
    );

    // ==========================================================================
    // INSTANTIATION 2: BLOCK 2 - PIPELINED SYSTOLIC FFT CORE
    // ==========================================================================
    bci_fft_engine u_fft_engine (
        .clk             (clk),
        .rst_n           (rst_n),
        .clk_gate_en_i   (icg_gate_en),         // Listens directly to the feedback power loop
        // Upstream Interface Connections
        .window_valid_i  (window_valid),
        .window_data_i   (window_data_stream),
        .fft_ready_o     (fft_ready),
        // Downstream Parallel Output Ports
        .fft_valid_o     (fft_valid),
        .fft_real_o      (fft_real_bus),
        .fft_imag_o      (fft_imag_bus)
    );

    // ==========================================================================
    // INSTANTIATION 3: BLOCK 3 - MULTIPLIERLESS MAC ENERGY TRACKER FILTER
    // ==========================================================================
    bci_energy_tracker u_energy_tracker (
        .clk             (clk),
        .rst_n           (rst_n),
        .clk_gate_en_i   (icg_gate_en),         // Listens directly to the feedback power loop
        // Upstream Spectrum Port Bundles
        .fft_valid_i     (fft_valid),
        .fft_real_i      (fft_real_bus),
        .fft_imag_i      (fft_imag_bus),
        // Downstream Arbitration Bus Ports
        .energy_valid_o  (energy_valid),
        .beta_energy_o   (beta_energy_bus)
    );

    // ==========================================================================
    // INSTANTIATION 4: BLOCK 4 - CLOSED-LOOP POWER ARBITRATION FSM
    // ==========================================================================
    bci_power_arbitrator u_power_arbitrator (
        .clk             (clk),
        .rst_n           (rst_n),
        // Downstream Measurement Sensor Wire Inputs
        .energy_valid_i  (energy_valid),
        .beta_energy_i   (beta_energy_bus),
        // Global Dynamic Control Rail Output Pins
        .hw_wake_o       (hw_wake_o),
        .icg_gate_en_o   (icg_gate_en)          // Feeds back into the global clock-gating lines
    );

endmodule
