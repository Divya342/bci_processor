module bci_power_arbitrator (
    input  logic        clk,               // Master System Clock (15.7 MHz)
    input  logic        rst_n,             // Asynchronous Active-Low Reset
    input  logic        energy_valid_i,    // Strobe confirming new frame energy is computed
    input  logic [31:0] beta_energy_i,     // 32-bit Unsigned Integer Energy Bus (Q6.24 scaled)
    output logic        hw_wake_o,         // Master power rail enable flag (0=Sleep, 1=Active)
    output logic        icg_gate_en_o      // Direct control wire to Integrated Clock Gating cells
);

    // Import global constants from your config package file
    import bci_config_pkg::*;

    // --- STATE MACHINE ENCODING (One-Hot for Extreme Power Optimization) ---
    typedef enum logic [1:0] {
        ST_DEEP_SLEEP  = 2'b01,            // Throttled clock-gated baseline state
        ST_ACTIVE_WAKE = 2'b10             // High-performance streaming/decoding state
    } state_t;

    state_t current_state, next_state;

    // Internal 2-bit counter to debounce biological noise glitches across multiple frames
    logic [1:0] frame_counter_r, frame_counter_next;

    // ==========================================================================
    // 1. SEQUENTIAL STATE REGISTER TRACK
    // ==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state   <= ST_DEEP_SLEEP;
            frame_counter_r <= 2'd0;
        end else begin
            current_state   <= next_state;
            frame_counter_r <= frame_counter_next;
        end
    end

    // ==========================================================================
    // 2. COMBINATIONAL STATE TRANSITION LOGIC MATRIX
    // ==========================================================================
    always_comb begin
        // Default assignments to safeguard against unintended latch synthesis
        next_state         = current_state;
        frame_counter_next = frame_counter_r;

        case (current_state)
            ST_DEEP_SLEEP: begin
                if (energy_valid_i) begin
                    // Reads the ENERGY_THRESHOLD_FIXED constant (143360) directly from package
                    if (beta_energy_i > ENERGY_THRESHOLD_FIXED) begin
                        // Debounce Filter: Requires consecutive frames to prevent power rail flickering
                        if (frame_counter_r >= DEBOUNCE_LIMIT - 1) begin
                            next_state         = ST_ACTIVE_WAKE;
                            frame_counter_next = 2'd0;
                        end else begin
                            frame_counter_next = frame_counter_r + 1'b1;
                        end
                    end else begin
                        frame_counter_next = 2'd0; // Reset noise counter if energy drops
                    end
                end
            end

            ST_ACTIVE_WAKE: begin
                if (energy_valid_i) begin
                    if (beta_energy_i <= ENERGY_THRESHOLD_FIXED) begin
                        if (frame_counter_r >= DEBOUNCE_LIMIT - 1) begin
                            next_state         = ST_DEEP_SLEEP;
                            frame_counter_next = 2'd0;
                        end else begin
                            frame_counter_next = frame_counter_r + 1'b1;
                        end
                    end else begin
                        frame_counter_next = 2'd0; // Reset counter if energy stays consistently high
                    end
                end
            end

            default: next_state = ST_DEEP_SLEEP;
        endcase
    end

    // ==========================================================================
    // 3. HARDWIRED STRUCTURAL OUTPUT DRIVERS
    // ==========================================================================
    // Status flag asserted to notify peripherals that decoding is active
    assign hw_wake_o = (current_state == ST_ACTIVE_WAKE);

    // ICG Control Wire: Asserted high during sleep to instruct standard library
    // clock-gating cells to completely freeze the clock lines of Blocks 2 & 3.
    assign icg_gate_en_o = (current_state == ST_DEEP_SLEEP);

endmodule
// Block 4: One-Hot Debounced FSM Controller Placeholder
