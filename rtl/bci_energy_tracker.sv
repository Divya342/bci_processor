`timescale 1ns / 1ps

module bci_power_arbitrator_netlist (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        energy_valid_i,
    input  wire [31:0] beta_energy_i,
    output wire        hw_wake_o,
    output wire        icg_gate_en_o
);

    // Internal net connections (wires physically routed between transistor gates)
    wire net_comparator_out;
    wire net_state_bit_0;
    wire net_state_bit_1;
    wire net_next_state_0;
    wire net_next_state_1;
    wire net_inv_rst;
    wire net_fsm_enable;

    // ==========================================================================
    // 1. HARDWIRED SPECTRUM COMPARATOR MESH
    // Evaluates: beta_energy_i > 32'd143360
    // ==========================================================================
    // Structural 32-bit digital magnitude comparator gate primitives array
    sky130_fd_sc_hd__magcomp_32 magnitude_check_0 (
        .A(beta_energy_i),
        .B(32'd143360),
        .GT(net_comparator_out)
    );

    // ==========================================================================
    // 2. STATE TRANSITION COMBINATIONAL GATE ARRAY
    // Maps the combinational logic rules of your One-Hot Encounced FSM
    // ==========================================================================
    // Invert the active-low reset pin for standard library clear ports
    sky130_fd_sc_hd__inv_1 rst_inverter (
        .A(rst_n),
        .Y(net_inv_rst)
    );

    // AND gate checking if data is valid and the magnitude comparator tripped high
    sky130_fd_sc_hd__and2_1 wake_trigger_gate (
        .A(energy_valid_i),
        .B(net_comparator_out),
        .X(net_fsm_enable)
    );

    // Structural combinational routing calculating Next State bits
    sky130_fd_sc_hd__xor2_1 next_state_bit0_logic (
        .A(net_state_bit_0),
        .B(net_fsm_enable),
        .X(net_next_state_0)
    );

    sky130_fd_sc_hd__and2_1 next_state_bit1_logic (
        .A(net_state_bit_1),
        .B(net_state_bit_0),
        .X(net_next_state_1)
    );

    // ==========================================================================
    // 3. PHYSICAL SEQUENTIAL STORAGE REGISTERS (D-Flip-Flop Standard Cells)
    // Instantiates the physical silicon storage elements for the FSM registers
    // ==========================================================================
    // State Bit 0 Register (ST_DEEP_SLEEP tracking bit)
    sky130_fd_sc_hd__dfp_1 state_reg_bit0 (
        .CLK(clk),
        .D(net_next_state_0),
        .RESET(net_inv_rst),
        .Q(net_state_bit_0)
    );

    // State Bit 1 Register (ST_ACTIVE_WAKE tracking bit)
    sky130_fd_sc_hd__dfp_1 state_reg_bit1 (
        .CLK(clk),
        .D(net_next_state_1),
        .RESET(net_inv_rst),
        .Q(net_state_bit_1)
    );

    // ==========================================================================
    // 4. CHIP OUTPUT BUFFER PIN DRIVERS
    // ==========================================================================
    // Buffers outputs to provide enough electrical current drive strength
    // to travel across the physical chip surface without signal degradation.
    sky130_fd_sc_hd__buf_2 wake_output_driver (
        .A(net_state_bit_1),
        .X(hw_wake_o)
    );

    sky130_fd_sc_hd__buf_2 icg_output_driver (
        .A(net_state_bit_0),
        .X(icg_gate_en_o)
    );

endmodule
