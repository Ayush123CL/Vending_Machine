# 🛒 Advanced Vending Machine Controller (Verilog)

![HDL](https://img.shields.io/badge/Language-Verilog-orange?style=flat-square)
![Simulation](https://img.shields.io/badge/Verified-Icarus_Verilog-green?style=flat-square)
![Category](https://img.shields.io/badge/Category-Embedded_Systems-blue?style=flat-square)

A high-reliability digital controller for a multi-product vending machine. This project focuses on a robust **Finite State Machine (FSM)** architecture and hardware-level signal conditioning.

---

## 🚀 Key Features

* **Multi-Product Logic:** Handles distinct pricing for Pens, Notebooks, Coke, Lays, and Water Bottles.
* **Mixed Payment Support:** Seamlessly integrates physical coin inputs (Rs 5, 10, 20, 50, 100) and instant online payment triggers.
* **Hardware Debouncing:** Includes a `DEBOUNCE_CYCLES` counter to filter out mechanical switch noise from coin sensors, preventing "double-counting" errors.
* **Automated Change Return:** Real-time calculation of excess balance dispensed via the `o_return_change` signal.
* **Safe-Fail Cancel:** Dedicated cancellation state ensuring a full refund if a transaction is aborted mid-payment.

---

## 📊 State Machine Architecture

The core of the system is a **Moore-type FSM**. Below is the logic flow representing the transitions from idle to product delivery.



| State | Description |
| :--- | :--- |
| **IDLE** | Standby mode. Resets all internal registers. |
| **SELECT_PRODUCT** | Decodes the 3-bit product input and assigns target price. |
| **_SELECTION_STATE** | Waits for coin inputs or online payment high. Monitors for `i_cancel`. |
| **DISPENSE_AND_RETURN**| High-level pulse for hardware delivery; calculates `Inserted - Price`. |
| **CANCEL** | Triggered on error or user cancel; returns all inserted coins instantly. |

---

## 🛠 Project Structure

* `VendingMachine.v`: Core RTL module containing the FSM and Debounce logic.
* `VendingMachine_tb.v`: Comprehensive testbench with 10 automated Test Cases (TCs).
* `vending_machine_tb.vcd`: Waveform file for timing analysis (viewable in GTKWave).

---

## 🧪 Verification & Test Cases

The design was validated against a rigorous test suite to ensure stability under edge cases:

| Case ID | Scenario | Expected Result |
| :--- | :--- | :--- |
| **TC03** | Overpayment (Rs 50 for Rs 35 Coke) | **PASS**: Product dispensed & Rs 15 returned. |
| **TC04** | Mid-payment Cancellation | **PASS**: Transaction aborted & partial payment refunded. |
| **TC08** | Noisy/Bouncing Coin Input | **PASS**: FSM ignored unstable pulses; waited for stable high. |
| **TC10** | Invalid Product Code | **PASS**: System safely returned to IDLE without error. |

---

## 💻 How to Use

### Prerequisites
* A Verilog simulator (e.g., Icarus Verilog or Vivado)
* A waveform viewer (e.g., GTKWave)

### Compilation & Simulation
1.  **Compile the design:**
    ```bash
    iverilog -o vm_sim VendingMachine.v VendingMachine_tb.v
    ```
2.  **Run the simulation:**
    ```bash
    vvp vm_sim
    ```
3.  **Analyze Waveforms:**
    Open the generated `.vcd` file in GTKWave to observe the state transitions.

---

## 👤 Author
**Ayush Moharana**
*Electronics Club, IIT Guwahati*
* **GitHub:** [Ayush123CL](https://github.com/Ayush123CL)
* **Project:** [RISC-V-Processor](https://github.com/Ayush123CL/RISC-V-Processor)
