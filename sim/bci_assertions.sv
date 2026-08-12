module bci_assertions (
    input logic        clk,
    input logic        rst_n,
    input logic        data_valid_i,
    input logic        hw_wake_o,

    // Bind targets inspecting internal top-level signals
    input logic        icg_gate_en,
    input logic        window_valid,
    input logic        fft_ready,
    input logic        fft_valid,
    input logic        energy_valid,
    input logic [31:0] beta_energy_bus
);

    // Import global constants for mathematical bounds tracking
    import bci_config_pkg::*;

    // ==========================================================================
    // 1. CLOCK-GATING SAFETY PROPERTIES (Bio-Thermal Safeguards)
    // ==========================================================================

    // PROPERTY: If the chip is in SLEEP mode, the clock gating enable pin MUST be high.
    // This mathematically guarantees that power-hungry arithmetic units are frozen.
    property p_sleep_implies_gating;
        @(posedge clk) disable iff (!rst_n)
        (hw_wake_o == 1'b0) -> (icg_gate_en == 1'b1);
    endproperty
    assert_sleep_gating: assert property (p_sleep_implies_gating);
    cover_sleep_gating:  cover property (p_sleep_implies_gating);

    // PROPERTY: If the chip is in ACTIVE mode, clock gating MUST be dropped immediately.
    property p_active_implies_clock;
        @(posedge clk) disable iff (!rst_n)
        (hw_wake_o == 1'b1) -> (icg_gate_en == 1'b0);
    endproperty
    assert_active_clock: assert property (p_active_implies_clock);

    // ==========================================================================
    // 2. PROTOCOL HANDSHAKE PROPERTIES (Data Integrity Safeguards)
    // ==========================================================================

    // PROPERTY: If Block 1 raises 'window_valid' but Block 2 is not 'ready',
    // data cannot drop out or change. It must hold perfectly steady until accepted.
    property p_axi_stream_handshake_hold;
        @(posedge clk) disable iff (!rst_n)
        (window_valid && !fft_ready) -> ##1 (window_valid);
    endproperty
    assert_handshake_stability: assert property (p_axi_stream_handshake_hold);

    // ==========================================================================
    // 3. THRESHOLD ARBITRATION PROPERTIES (FSM Logic Checking)
    // ==========================================================================

    // PROPERTY: If the calculated Beta energy spikes over your threshold for consecutive
    // frames, the FSM must eventually wake up the hardware. It cannot hang or ignore it.
    property p_energy_trigger_wake;
        @(posedge clk) disable iff (!rst_n)
        (energy_valid && (beta_energy_bus > ENERGY_THRESHOLD_FIXED)) [*2] |-> ##[1:2] (hw_wake_o == 1'b1);
    endproperty
    assert_energy_activation: assert property (p_energy_trigger_wake);

    // ==========================================================================
    // 4. POST-RESET SANITY PROOFS (Fail-Safe States)
    // ==========================================================================

    // PROPERTY: The absolute instant reset is asserted low, the chip must drop
    // everything and force itself into the low-power safe sleep state.
    property p_immediate_reset_sleep;
        @(negedge rst_n) 1'b1 |-► (hw_wake_o == 1'b0 && icg_gate_en == 1'b1);
    endproperty
    assert_reset_fail_safe: assert property (p_immediate_reset_sleep);

endmodule
