`ifndef BCI_SCOREBOARD_SV
`define BCI_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

// Forward declaration of the transaction type
`uvm_analysis_imp_decl(_input_port)
`uvm_analysis_imp_decl(_output_port)

class bci_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(bci_scoreboard)

    // --- UVM IMPERIAL LISTENING PORTS ---
    // Connects to the upstream monitors to spy on incoming and outgoing transactions
    uvm_analysis_imp_input_port  #(bci_transaction, bci_scoreboard) input_export;
    uvm_analysis_imp_output_port #(bci_transaction, bci_scoreboard) output_export;

    // --- VERIFICATION TELEMETRY ANALYSIS MATRIX ---
    integer      golden_file_pointer;
    integer      scan_status;
    real         expected_time;
    integer      expected_state;

    integer      match_count = 0;
    integer      error_count = 0;

    // --- CONSTRUCTOR ---
    function new(string name = "bci_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    // --- UVM BUILD PHASE ---
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        input_export  = new("input_export", this);
        output_export = new("output_export", this);
    endfunction : build_phase

    // --- UVM CONNECT PHASE (File Streaming Ingestion) ---
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Open your verification reference tracker file generated in PyCharm
        golden_file_pointer = $fopen("expected_fsm_output.txt", "r");
        if (golden_file_pointer == 0) begin
            `uvm_fatal("SC_FILE_ERROR", "Could not locate 'expected_fsm_output.txt' reference matrix inside sim/ directory!")
        end else begin
            `uvm_info("SC_START", "Successfully mapped expected golden targets array for runtime comparison.", UVM_LOW)
        end
    endfunction : connect_phase

    // ==========================================================================
    // ANALYSIS CHANNEL 1: INPUT RECORDING INTERCONNECT
    // ==========================================================================
    virtual function void write_input_port(bci_transaction tr);
        // Passive hook: can be utilized to log total input packet history tracking
    endfunction : write_input_port

    // ==========================================================================
    // ANALYSIS CHANNEL 2: REAL-TIME OUTPUT CHECKS (The Silicon Judge Logic)
    // ==========================================================================
    virtual function void write_output_port(bci_transaction tr);
        if (!$feof(golden_file_pointer)) begin
            // Read the next sequential line of your verification reference matrix
            scan_status = $fscanf(golden_file_pointer, "%f %d\n", expected_time, expected_state);

            if (scan_status == 2) begin
                match_count++;

                // CRITICAL BIT-CHECK COMPARATOR GATE
                // Compares the real-world output bit from SystemVerilog with the Python target
                if (tr.hw_power_state !== expected_state) begin
                    error_count++;
                    `uvm_error("BCI_MATH_MISMATCH", $sformatf("MISMATCH DETECTED! Time: %0t ns | Target Frame Marker: %0.4fs | Expected FSM State: %0d | Physical Silicon Pin Out: %0d",
                               $time, expected_time, expected_state, tr.hw_power_state))
                end else begin
                    `uvm_info("BCI_MATCH_OK", $sformatf("PASS: Frame Verification Point %0d aligned. Target: %0d | Pin: %0d",
                              match_count, expected_state, tr.hw_power_state), UVM_HIGH)
                end
            end
        end
    endfunction : write_output_port

    // --- UVM REPORT PHASE (The Final Grading Sign-Off) ---
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        $fclose(golden_file_pointer);
        `uvm_info("SC_SUMMARY", "--------------------------------------------------------", UVM_LOW)
        `uvm_info("SC_SUMMARY", $sformatf(" UVM SCOREBOARD REPORT SIGN-OFF SUMMARY FOR BCI CORE:"), UVM_LOW)
        `uvm_info("SC_SUMMARY", $sformatf("  -> TOTAL EVALUATION FRAMES EXTRACTED: %0d", match_count), UVM_LOW)
        `uvm_info("SC_SUMMARY", $sformatf("  -> VERIFIED ADVANCED HARDWARE MATCHES: %0d", (match_count - error_count)), UVM_LOW)
        `uvm_info("SC_SUMMARY", $sformatf("  -> MATH OVERFLOW OR STATE BIT MISMATCHES: %0d", error_count), UVM_LOW)
        `uvm_info("SC_SUMMARY", "--------------------------------------------------------", UVM_LOW)

        if (error_count > 0) begin
            `uvm_fatal("ASIC_TAPE_OUT_FAIL", "Synthesis blocked. Hardware logic mismatches found against the Python Gold Model!")
        end else begin
            `uvm_info("ASIC_TAPE_OUT_PASSED", "TAPE-OUT APPROVED: 100% bit-exact compliance achieved across all neural matrix tracks.", UVM_LOW)
        end
    endfunction : report_phase

endclass : bci_scoreboard

`endif // BCI_SCOREBOARD_SV
