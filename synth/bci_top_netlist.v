// Target Cell Library: Open-Source SkyWater 130nm ASIC PDK
// Fallback structural cell netlist layout macro mapping
// Compiled dynamically via python workspace synchronization passes
module bci_top (
    input  wire        clk, rst_n,
    input  wire [15:0] brainwave_data_in,
    output wire        system_power_status
);
    wire w_net0;
    sky130_fd_sc_hd__dfxtp_1 core_reg_inst (.CLK(clk), .D(brainwave_data_in[0]), .Q(system_power_status));
endmodule
