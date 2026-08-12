`ifndef BCI_ENV_SV
`define BCI_ENV_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class bci_env extends uvm_env;
    `uvm_component_utils(bci_env)

    // --- INSTANTIATION OF UVM SUBCONSTITUENTS ---
    bci_driver                                     u_driver;
    bci_monitor                                    u_monitor;
    bci_scoreboard                                 u_scoreboard;
    uvm_sequencer #(bci_transaction)               u_sequencer;

    // --- CONSTRUCTOR ---
    function new(string name = "bci_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    // ==========================================================================
    // 1. BUILD PHASE (Factory Allocation Layout)
    // ==========================================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        `uvm_info("ENV_BUILD", "Allocating environment structural nodes inside the factory...", UVM_LOW)
        u_driver     = bci_driver::type_id::create("u_driver", this);
        u_monitor    = bci_monitor::type_id::create("u_monitor", this);
        u_scoreboard = bci_scoreboard::type_id::create("u_scoreboard", this);
        u_sequencer  = uvm_sequencer#(bci_transaction)::type_id::create("u_sequencer", this);
    endfunction : build_phase

    // ==========================================================================
    // 2. CONNECT PHASE (Dynamic Analysis Port Cross-Wiring)
    // ==========================================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("ENV_CONNECT", "Stitching communication buses between active components...", UVM_LOW)

        // Wire Link A: Hook the Driver to the Sequencer data pipeline stream
        u_driver.seq_item_port.connect(u_sequencer.seq_item_export);

        // Wire Link B: Hook the Monitor's passive broadcasting port directly to the
        // Scoreboard's judge input ports to enable live tracking matrix checks
        u_monitor.item_collected_port.connect(u_scoreboard.output_export);
    endfunction : connect_phase

endclass : bci_env

`endif // BCI_ENV_SV
