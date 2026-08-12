// SystemVerilog guard to prevent duplicate compilation errors
`ifndef BCI_TRANSACTION_SV
`define BCI_TRANSACTION_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class bci_transaction extends uvm_sequence_item;

    // --- RANDOMIZED HARDWARE ATTRIBUTES (The Data Payload) ---
    // Models a 16-bit signed Q3.12 voltage sample coming from the brain electrodes
    rand logic signed [15:0] data_sample;

    // --- CONSTRAINED RANDOMIZATION MATRICES (Biological Emulation) ---
    // Prevents random testing from generating illegal or unrealistic numbers.
    // Constrains random values to fit inside the signed 16-bit integer boundaries.
    constraint c_voltage_range {
        data_sample >= -16'sh8000;
        data_sample <=  16'sh7FFF;
    }

    // --- TELEMETRY AND ANALYSIS ATTRIBUTES ---
    // Captured by the verification monitor to check timing alignment
    realtime timestamp;
    logic    hw_power_state; // Monitors if the chip was awake or asleep during packet entry

    // --- UVM MACRO REGISTRATION ---
    // Registers the class with the UVM factory to allow dynamic configuration swaps
    `uvm_object_utils_begin(bci_transaction)
        `uvm_field_int(data_sample,    UVM_DEFAULT | UVM_SIGNED)
        `uvm_field_int(hw_power_state, UVM_DEFAULT)
        `uvm_field_real(timestamp,     UVM_DEFAULT)
    `uvm_object_utils_end

    // --- CONSTRUCTOR ---
    function new(string name = "bci_transaction");
        super.new(name);
    endfunction : new

endclass : bci_transaction

`endif // BCI_TRANSACTION_SV
