`ifndef BCI_DRIVER_SV
`define BCI_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class bci_driver extends uvm_driver #(bci_transaction);
    `uvm_component_utils(bci_driver)

    // --- VIRTUAL INTERFACE CONNECTION ---
    // Acts as the physical copper wiring loom connecting this class to the chip pins
    virtual interface bci_if vif;

    // --- CONSTRUCTOR ---
    function new(string name = "bci_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    // --- UVM RUN PHASE (The Active Injection Loop) ---
    virtual task run_phase(uvm_phase phase);
        bci_transaction req_trans;

        // Reset the interface to a safe baseline state
        vif.data_valid <= 1'b0;
        vif.data_in    <= 16'sh0000;

        // Wait for the master reset line to lift before pumping data
        @(posedge vif.rst_n);
        `uvm_info("DRV_START", "Asynchronous reset lifted. Initializing driver transaction loop.", UVM_LOW)

        forever begin
            // 1. Fetch the next transaction object from the verification sequencer
            seq_item_port.get_next_item(req_trans);

            // 2. Synchronize to the positive edge of the 15.7 MHz master hardware clock
            @(posedge vif.clk);

            // 3. Drive the virtual data objects directly onto the physical RTL input pins
            vif.data_valid <= 1'b1;
            vif.data_in    <= req_trans.data_sample;

            // 4. Hold the pin values steady for exactly one clock cycle
            @(posedge vif.clk);
            vif.data_valid <= 1'b0; // Drop strobe to mimic a real streaming ADC cycle

            // 5. Signal the sequencer that this packet has been successfully injected
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : bci_driver

`endif // BCI_DRIVER_SV
