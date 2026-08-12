`timescale 1ns / 1ps
module uvm_tb_top;

    // Import global constants for configuration syncing
    import bci_config_pkg::*;

    // ==========================================================================
    // 1. MASTER WIRE AND REGISTER DECLARATIONS (ASIC Pin Mapping)
    // ==========================================================================
    logic        clk_r;                  // Master hardware clock register
    logic        rst_n_r;                // Master asynchronous active-low reset
    logic        data_valid_r;           // Input strobe to feed Block 1 SRAM
    logic [15:0] data_in_r;              // 16-bit Signed Q3.12 input data bus
    logic        hw_wake_w;              // Master telemetry output from the ASIC

    // ==========================================================================
    // 2. CLOCK GENERATOR MATRIX (15.7 MHz Target Engine)
    // ==========================================================================
    // Math: 15.7 MHz corresponds to a clock period of exactly 63.694 nanoseconds.
    // 63.694 / 2 = 31.847 ns for a perfectly symmetric 50% duty cycle toggle.
    initial begin
        clk_r = 1'b0;
        forever #31.847 clk_r = ~clk_r;
    end

    // ==========================================================================
    // 3. DESIGN UNDER TEST (DUT) INSTANTIATION
    // ==========================================================================
    // Connects your top-level silicon circuit board directly to the test bench wires
    bci_top u_bci_top (
        .clk          (clk_r),
        .rst_n        (rst_n_r),
        .data_valid_i (data_valid_r),
        .data_in_i    (data_in_r),
        .hw_wake_o    (hw_wake_w)
    );

    // ==========================================================================
    // 4. FORMAL SVA CHECKER BINDING
    // ==========================================================================
    // Forcefully cross-wires the bci_assertions checker block to inspect the
    // internal nodes of your chip without modifying the human RTL source code.
    bci_assertions u_assertions_bind (
        .clk              (clk_r),
        .rst_n            (rst_n_r),
        .data_valid_i     (data_valid_r),
        .hw_wake_o        (hw_wake_w),
        // Snooping internal structural tracks directly via hierarchy paths
        .icg_gate_en      (u_bci_top.icg_gate_en),
        .window_valid     (u_bci_top.window_valid),
        .fft_ready        (u_bci_top.fft_ready),
        .fft_valid        (u_bci_top.fft_valid),
        .energy_valid     (u_bci_top.energy_valid),
        .beta_energy_bus  (u_bci_top.beta_energy_bus)
    );

    // ==========================================================================
    // 5. STEP 4 ALGORITHMIC VERIFICATION TASK (File I/O Stream Injection)
    // ==========================================================================
    integer file_pointer;
    integer scan_status;
    integer signed file_data_buffer;
    integer clock_cycle_count = 0;

    initial begin
        // A. Set Safe Initial State Conditions
        rst_n_r      = 1'b0; // Force immediate active-low reset
        data_valid_r = 1'b0;
        data_in_r    = 16'd0;

        #200;                // Hold reset for 200 nanoseconds to clear all arrays
        rst_n_r      = 1'b1; // De-assert reset to boot up the state machines
        #50;

        // B. Open your Serialized Text Vectors from Step 2
        // Looks straight inside your local sim/ directory for the input stimulus
        file_pointer = $fopen("input_stimulus.txt", "r");
        if (file_pointer == 0) begin
            $display("[FATAL ERROR]: Could not locate 'input_stimulus.txt'. Ensure file exists in sim/ directory.");
            $finish;
        end else begin
            $display("[TESTBENCH START]: Initializing raw vector stream injection...");
        end

        // C. Continuous Clock Injection Loop
        // Feeds 1 data word to the chip pins on every positive clock edge
        while (!$feof(file_pointer)) begin
            @(posedge clk_r);

            // Read a single line integer value from the vector file
            scan_status = $fscanf(file_pointer, "%d\n", file_data_buffer);

            if (scan_status == 1) begin
                data_valid_r      = 1'b1;
                data_in_r         = file_data_buffer[15:0]; // Cast to 16-bit signed vector width
                clock_cycle_count = clock_cycle_count + 1;
            end
        end

        // D. Final Simulation Wrap Up and Sign-off
        @(posedge clk_r);
        data_valid_r = 1'b0;
        $fclose(file_pointer);

        $display("[TESTBENCH SUCCESS]: Successfully processed %d neural clock cycles through the ASIC pipelines.", clock_cycle_count);
        $display("[TESTBENCH SUCCESS]: Check waveform simulator against 'expected_fsm_output.txt' to sign off.");
        #1000;
        $finish;
    end

endmodule
