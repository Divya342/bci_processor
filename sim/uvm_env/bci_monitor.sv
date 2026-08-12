`ifndef BCI_MONITOR_SV
`define BCI_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class bci_monitor extends uvm_monitor;
    `uvm_component_utils(bci_monitor)

    // --- VIRTUAL INTERFACE CONNECTION ---
    virtual interface bci_if vif;

    // --- UVM BROADCAST PORTS ---
    // Broadcast channels that push packed data objects straight to the Scoreboard
    uvm_analysis_port #(bci_transaction) item_collected_port;

    // --- CONSTRUCTOR ---
    function new(string name = "bci_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction : new

    // --- UVM RUN PHASE (The Passive Snooping Loop) ---
    virtual task run_phase(uvm_phase phase);
        bci_transaction cloned_trans;

        // Wait for reset to clear
        @(posedge vif.rst_n);
        `uvm_info("MON_START", "Monitor active. Snooping data buses for state arbitration metrics.", UVM_LOW)

        forever begin
            // Synchronize with the master clock
            @(posedge vif.clk);

            // Passive Monitoring Condition: If the input validity line is active, capture the pin state
            if (vif.data_valid === 1'b1) begin
                // 1. Create a brand new, clean transaction object instance from the factory
                cloned_trans = bci_transaction::type_id::create("cloned_trans");

                // 2. Read and log the exact hardware snapshots from the physical pins
                cloned_trans.data_sample    = vif.data_in;
                cloned_trans.hw_power_state = vif.hw_wake; // Capture whether the FSM output bit is 0 or 1
                cloned_trans.timestamp      = $realtime;    // Log the exact simulation nanosecond

                // 3. Broadcast this structural frame object out to the Scoreboard judge channel
                item_collected_port.write(cloned_trans);
            end
        end
    endtask : run_phase

endclass : bci_monitor

`endif // BCI_MONITOR_SV
