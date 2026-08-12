`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: bci_uvm_pkg (Master Verification Package)
// Description: Compiles all decoupled UVM object assets into a single clean namespace.
//////////////////////////////////////////////////////////////////////////////////

package bci_uvm_pkg;
    import uvm_pkg::*;
    import bci_config_pkg::*;

    `include "uvm_macros.svh"
    `include "bci_transaction.sv"
    `include "bci_driver.sv"
    `include "bci_monitor.sv"
    `include "bci_scoreboard.sv"
    `include "bci_env.sv"

endpackage : bci_uvm_pkg
