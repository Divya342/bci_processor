# Parameterized Real-Time BCI Core Processor & Automated ASIC Synthesis Pipeline

An independent hardware-software co-designed digital signal processing (DSP) accelerator engineered to execute real-time spectral decomposition on streaming multi-channel neural biosignals (LFPs/ECoG) for implantable neuro-prosthetic payloads. 

The workspace features a single-source-of-truth JSON configuration topology paired with an automated Python orchestrator script (`run_all.py`). This pipeline maps continuous biological brainwaves into bit-exact fixed-point arrays, verifies multi-tier directory dependencies, and executes ASIC logic synthesis targets compiling abstract SystemVerilog code down to an optimized, gate-level standard cell netlist file.

---

## 📂 Repository Topology & File Descriptions

```text
bci-processor/                          <-- [ROOT DIRECTORY]
│
├── run_all.py                          <-- Master Co-Design Automation Orchestrator Script
├── README.md                           <-- Technical Specification & Research Abstract
│
├── config/                             # Central System Hardware Parameter Manifests
│   └── bci_config_pkg.json             # Single-Source-of-Truth global design parameters
│
├── rtl/                                # Synthesizable SystemVerilog IP Hardware Cores
│   ├── bci_window_buffer.sv            # Block 1: 1024-Word Circular Dual-Port Ingestion RAM
│   ├── bci_fft_engine.sv               # Block 2: 10-Stage Radix-2 Systolic Real-FFT Accelerator
│   ├── bci_energy_tracker.sv           # Block 3: Multiplierless Absolute-Value MAC Filter
│   ├── bci_power_arbitrator.sv         # Block 4: Closed-Loop Clock Gating FSM Controller
│   └── bci_top.sv                      # Master Structural Chip Interconnect Wrapper
│
├── sim/                                # Advanced Verification & UVM Simulation Assets
│   ├── uvm_tb_top.sv                   # Master Verification Testbench Clock Wrapper Container
│   ├── bci_assertions.sv               # Formal Verification (SystemVerilog Assertions Core)
│   └── uvm_env/                        # Universal Verification Methodology (UVM) Package
│       ├── bci_transaction.sv          # Randomized 1024-word fixed-point sequence items
│       ├── bci_driver.sv               # AXI-Stream Protocol Handshake Interface Driver
│       ├── bci_monitor.sv              # Post-Layout Parallel Output Bus Signal Tracker
│       ├── bci_scoreboard.sv           # 1:1 Reference Comparator Matrix Scoreboard Core
│       ├── bci_env.sv                  # Component Wiring Interconnect Layer Object
│       └── bci_uvm_pkg.sv              # Master Verification Package Compiler Namespace
│
├── synth/                              # Physical Deliverables & Pre-Layout Synthesis Tools
│   ├── constraints.sdc                 # Synopsys Design Constraints (SDC) clock targets
│   ├── power_domains.upf               # Unified Power Format (UPF) power-gating boundaries
│   ├── bci_top_netlist.v               # OUTPUT: Compiled Gate-Level Structural Verilog Map
│   └── scripts/                        # Automated Synthesis Compiler Infrastructure
│       └── synthesis_run.tcl           # Tcl Synthesis command automation run-script
│
├── layout/                             # Backend Physical Design & Place-and-Route Data
│   ├── floorplan.json                  # Pad ring macro placement and die grid constraints
│   ├── clock_tree.json                 # Clock Tree Synthesis (CTS) buffer insertion layout
│   └── verification_signoff/           # Manufacturing Sign-Off Verification Logs
│       ├── drc_report.log              # Siemens Calibre Geometric Design Rule Check log
│       └── lvs_report.log              # Siemens Calibre Layout Versus Schematic match log
│
└── software_model/                     # Algorithmic Reference Prototyping Environment
     ├── bci_math_simulation.py         # Floating-point Python scientific reference model
     ├── Algorithmic Verification Scripts.py # Continuous signal validation routines
     ├── bci_fixed_point_model.py       # Bit-exact Q3.12 numerical quantization tracker
     └── Signal Serialization.py        # Brainwave-to-Hex vector text string exporter
```

---

## 🛠️ Microarchitectural Architecture Overview ($N = 1024$)

*   **Fixed-Point Precision Boundaries**: Locked to a 16-bit wide, signed fixed-point configuration ($Q3.12$ representation) yielding a quantization resolution of $244.14\,\mu\text{V}$ with strict input clamping boundaries to eliminate saturation clipping.
*   **Ingestion Window Sizing**: Features an upgraded **1024-word memory block size** ($N=1024$) to capture high-density spectral traces. Memory operations are split across a dual-port RAM framework inside `bci_window_buffer.sv` with a 32-sample sliding update window stride to sustain continuous biological tracking.
*   **Logarithmic Math Loop Pipeline**: Expanded from legacy code limits to support exactly **10 distinct execution stages** ($\log_2(1024) = 10$). Sub-FSM counters utilize an updated 4-bit register configuration (`logic [3:0] stage_counter_r`) tracking loop limits incrementally from `0` to `9` to eliminate binary overflow freeze faults.
*   **Bus Real Estate Optimization**: Utilizes an unrolled generate block inside `bci_fft_engine.sv` to prune conjugate-symmetric frequency outputs. This forcefully drops mirrored bins 514–1023, reducing active cross-chip trace routing by 49.2% by exporting only the 513 unique real frequency bins.

---

## 🚀 Execution, Automation & Verification Workflow

The master Python execution framework orchestrates the entire cross-domain design pipeline automatically upon invocation:

### 1. Script Boot and Directory Initialization (`run_all.py`)
Run the master framework driver script from your terminal shell environment:
```bash
python run_all.py
```
On boot, the environment applies dynamic absolute path resolution anchors, setting your primary working tree directly over `bci-processor/` to guarantee absolute compatibility across Windows and Linux environments.

### 2. Analytical Signal Serialization
The pipeline calls the components tucked inside `/software_model/` to synthesize continuous multi-wave brainwave configurations (Alpha, Beta, and Mu channels) mixed with active $1/f^\alpha$ biological pink background noise. The floating-point values are passed to the quantization engine, scaled by a factor of 4096, and serialized out as integer data sheets inside your local `/sim` tracking directory.

### 3. Structural Environment Audit Scan
The pipeline walks through an automated dependency check, verifying files within the `/rtl/` block before stepping down into the deep nested subdirectories (`sim/uvm_env/`) to validate your newly added UVM infrastructure assets. If files match successfully, the terminal window clears the check and flags status verification.

### 4. ASIC Logic Synthesis & Sign-Off Mapping
The automation core passes parameters extracted from your single-source-of-truth config matrix file into your Tcl/Python subprocess compilers. Abstract SystemVerilog blocks are evaluated, optimized under high power effort parameters, and output as a gate-level structural cell mapping netlist (`synth/bci_top_netlist.v`) linked to target **SkyWater 130nm ASIC Process Design Kit** macros. 

The pipeline completes by scanning your backend physical layouts, checking manufacturing geometry logs, and confirming full **DRC & LVS sign-off verification compliance (Exit Code = 0)**.
