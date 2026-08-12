module bci_window_buffer (
    input  logic                     clk,             // Master System Clock (15.7 MHz)
    input  logic                     rst_n,           // Asynchronous Active-Low Reset

    // --- ELECTRODE STREAM INTERFACE ---
    input  logic                     data_valid_i,    // High when electrode has a steady sample
    input  logic signed [15:0]       data_in_i,       // 16-bit Signed Q3.12 incoming brainwave integer

    // --- DOWNSTREAM FFT INTERFACE HANDSHAKE ---
    input  logic                     fft_ready_i,     // Handshake: High when Block 2 can accept a window
    output logic                     window_valid_o,  // Handshake: High when steady data sits on output bus
    output logic signed [15:0]       window_data_o    // Serial stream output of the full 128-word packet
);

    // Import global constants (WINDOW_SIZE = 1024, STRIDE_SIZE = 32, DATA_WIDTH = 16)
    import bci_config_pkg::*;

    // --- INTERNAL STORAGE ARCHITECTURE (Dual-Port SRAM Emulation Matrix) ---
    // Physical 128-word static memory track
    logic signed [DATA_WIDTH-1:0] sram_bank [0:WINDOW_SIZE-1];

    // --- CIRCULAR STORAGE POINTERS ---
    logic [6:0] write_ptr_r;              // Tracks the absolute next slot to fill (0 to 127)
    logic [6:0] read_ptr_r;               // Tracks the burst data readout index
    logic [4:0] stride_counter_r;         // Counts up to 32 to track window stride steps

    // --- CONTROL LOGIC STATES ---
    typedef enum logic {
        ST_IDLE   = 1'b0,                 // Passive write/fill tracking state
        ST_BURST  = 1'b1                  // Active fast read-burst transmission state
    } buffer_state_t;

    buffer_state_t current_state, next_state;
    logic [6:0]    burst_counter_r, burst_counter_next;
    logic          initial_fill_done_r;   // Ensures the chip has a full 128 points before first trigger

    // ==========================================================================
    // 1. SEQUENTIAL PIPELINE TRACK (Register Flip-Flop Updates)
    // ==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_r         <= 7'd0;
            read_ptr_r          <= 7'd0;
            stride_counter_r    <= 5'd0;
            current_state       <= ST_IDLE;
            burst_counter_r     <= 7'd0;
            initial_fill_done_r <= 1'b0;
        end else begin
            current_state       <= next_state;
            burst_counter_r     <= burst_counter_next;

            // Port 1: Handle input serial data writes to the circular memory matrix
            if (data_valid_i) begin
                sram_bank[write_ptr_r] <= data_in_i;

                // Advance the circular buffer write pointer (wraps around automatically at 127)
                if (write_ptr_r == (WINDOW_SIZE - 1)) begin
                    write_ptr_r         <= 7'd0;
                    initial_fill_done_r <= 1'b1; // Memory bank is full of historical traces
                end else begin
                    write_ptr_r         <= write_ptr_r + 1'b1;
                end

                // Stride tracking: Increment count to watch for the 32-cycle update boundary
                if (stride_counter_r == (STRIDE_SIZE - 1)) begin
                    stride_counter_r <= 5'd0;
                end else begin
                    stride_counter_r <= stride_counter_r + 1'b1;
                end
            end

            // Port 2: Handle active readout pointers during transmission bursts
            if (current_state == ST_BURST && fft_ready_i) begin
                if (read_ptr_r == (WINDOW_SIZE - 1)) begin
                    read_ptr_r <= 7'd0;
                end else begin
                    read_ptr_r <= read_ptr_r + 1'b1;
                end
            end else if (current_state == ST_IDLE) begin
                // Synchronize the start of the read pointer to the oldest point in the sliding frame
                read_ptr_r <= write_ptr_r;
            end
        end
    end

    // ==========================================================================
    // 2. STATE MACHINE COMBINATIONAL MACHINE (Handshake Matrix Control)
    // ==========================================================================
    always_comb begin
        next_state         = current_state;
        burst_counter_next = burst_counter_r;
        window_valid_o     = 1'b0;

        case (current_state)
            ST_IDLE: begin
                // Condition: 32 cycles have passed, the bank has historical data, and the FFT core is ready
                if (data_valid_i && (stride_counter_r == (STRIDE_SIZE - 1)) && initial_fill_done_r && fft_ready_i) begin
                    next_state         = ST_BURST;
                    burst_counter_next = 7'd0;
                end
            end

            ST_BURST: begin
                window_valid_o = 1'b1; // Drive the AXI-Valid flag high to signal downstream blocks

                if (fft_ready_i) begin
                    if (burst_counter_r == (WINDOW_SIZE - 1)) begin
                        next_state         = ST_IDLE;
                        burst_counter_next = 7'd0;
                    end else begin
                        burst_counter_next = burst_counter_r + 1'b1;
                    end
                end
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // ==========================================================================
    // 3. SRAM DATA OUTPUT BUS WIRING
    // ==========================================================================
    // Links output data stream pin to the address location tracked by the read burst pointer
    assign window_data_o = sram_bank[read_ptr_r];

endmodule
// Block 1: Dual-Port Interleaved SRAM Buffer Placeholder
