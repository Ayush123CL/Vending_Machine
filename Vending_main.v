`timescale 1ns / 1ps

// =============================================================================
// Vending Machine FSM
// Fixes applied:
//   1. Added CANCEL_STATE so refund is properly output on cancellation
//   2. Return change is calculated at transition time (not one cycle late)
//   3. o_product_price is now visible during all product selection states
//   4. Fixed 1'b0 -> 7'd0 for 7-bit output signals
//   5. Added coin debounce mechanism (stability counter)
// =============================================================================

module VendingMachine #(
    parameter WATER_BOTTLE_PRICE = 7'd20,
    parameter PEN_PRICE          = 7'd10,
    parameter NOTEBOOK_PRICE     = 7'd50,
    parameter COKE_PRICE         = 7'd35,
    parameter LAYS_PRICE         = 7'd20,
    parameter DEBOUNCE_CYCLES    = 4'd8   // Coin must be stable for N cycles
)
(
    // Global signals
    input  wire         i_clk,              // Clock signal
    input  wire         i_rst,              // Reset signal (Active High)

    // Inputs
    input  wire         i_start,            // Start signal
    input  wire         i_cancel,           // Cancel signal
    input  wire [2:0]   i_product_code,     // Product selection input signal
    input  wire         i_online_payment,   // Online payment signal
    input  wire [6:0]   i_total_coin_value, // Total amount of valid coins inserted

    // Outputs
    output wire [3:0]   o_state,            // Indicates current state
    output wire         o_dispense_product, // High when dispensing product
    output wire [6:0]   o_return_change,    // Return change value
    output wire [6:0]   o_product_price     // Price of the selected product
);

    // -------------------------------------------------------------------------
    // State Encoding
    // -------------------------------------------------------------------------
    localparam IDLE_STATE                   = 4'b0000,
               SELECT_PRODUCT_STATE         = 4'b0001,
               PEN_SELECTION_STATE          = 4'b0010,
               NOTEBOOK_SELECTION_STATE     = 4'b0011,
               COKE_SELECTION_STATE         = 4'b0100,
               LAYS_SELECTION_STATE         = 4'b0101,
               WATER_BOTTLE_SELECTION_STATE = 4'b0110,
               DISPENSE_AND_RETURN_STATE    = 4'b0111,
               CANCEL_STATE                 = 4'b1000; // FIX 1: dedicated cancel/refund state

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    reg [3:0] r_state,          r_next_state;
    reg [6:0] r_return_change,  r_next_return_change;
    reg [6:0] r_product_price,  r_next_product_price;

    // FIX 5: Debounce registers -- ensure coin value is stable before accepting
    reg [6:0] r_coin_prev;          // Previous coin value
    reg [3:0] r_debounce_count;     // Stability counter
    reg [6:0] r_stable_coin_value;  // Debounced (stable) coin value
    reg       r_coin_stable;        // High when coin value has been stable long enough

    // -------------------------------------------------------------------------
    // Coin Debounce Logic (Sequential)
    // -------------------------------------------------------------------------
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_coin_prev         <= 7'd0;
            r_debounce_count    <= 4'd0;
            r_stable_coin_value <= 7'd0;
            r_coin_stable       <= 1'b0;
        end else begin
            if (i_total_coin_value != r_coin_prev) begin
                // Coin value changed - restart stability counter
                r_coin_prev      <= i_total_coin_value;
                r_debounce_count <= 4'd0;
                r_coin_stable    <= 1'b0;
            end else if (r_debounce_count < DEBOUNCE_CYCLES) begin
                // Still counting stability cycles
                r_debounce_count <= r_debounce_count + 4'd1;
                r_coin_stable    <= 1'b0;
            end else begin
                // Value has been stable long enough - accept it
                r_stable_coin_value <= i_total_coin_value;
                r_coin_stable       <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // State Register Update (Sequential)
    // -------------------------------------------------------------------------
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_state         <= IDLE_STATE;
            r_product_price <= 7'd0;
            r_return_change <= 7'd0;
        end else begin
            r_state         <= r_next_state;
            r_return_change <= r_next_return_change;
            r_product_price <= r_next_product_price;
        end
    end

    // -------------------------------------------------------------------------
    // Next-State & Datapath Logic (Combinational)
    // -------------------------------------------------------------------------
    always @(*) begin
        // Default: hold current values
        r_next_state         = r_state;
        r_next_return_change = r_return_change;
        r_next_product_price = r_product_price;

        case (r_state)

            // -----------------------------------------------------------------
            IDLE_STATE: begin
                r_next_return_change = 7'd0;
                r_next_product_price = 7'd0;
                if (i_start)
                    r_next_state = SELECT_PRODUCT_STATE;
                else
                    r_next_state = IDLE_STATE;
            end

            // -----------------------------------------------------------------
            SELECT_PRODUCT_STATE: begin
                if (i_cancel)
                    r_next_state = IDLE_STATE;  // No coins inserted yet, just go idle
                else begin
                    case (i_product_code)
                        3'b000: begin
                            r_next_state         = PEN_SELECTION_STATE;
                            r_next_product_price = PEN_PRICE;
                        end
                        3'b001: begin
                            r_next_state         = NOTEBOOK_SELECTION_STATE;
                            r_next_product_price = NOTEBOOK_PRICE;
                        end
                        3'b010: begin
                            r_next_state         = COKE_SELECTION_STATE;
                            r_next_product_price = COKE_PRICE;
                        end
                        3'b011: begin
                            r_next_state         = LAYS_SELECTION_STATE;
                            r_next_product_price = LAYS_PRICE;
                        end
                        3'b100: begin
                            r_next_state         = WATER_BOTTLE_SELECTION_STATE;
                            r_next_product_price = WATER_BOTTLE_PRICE;
                        end
                        default: begin
                            r_next_state         = IDLE_STATE;
                            r_next_product_price = 7'd0;
                        end
                    endcase
                end
            end

            // -----------------------------------------------------------------
            // Shared payment-wait handler for all product states
            // -----------------------------------------------------------------
            PEN_SELECTION_STATE,
            NOTEBOOK_SELECTION_STATE,
            COKE_SELECTION_STATE,
            LAYS_SELECTION_STATE,
            WATER_BOTTLE_SELECTION_STATE: begin

                if (i_cancel) begin
                    // FIX 1: Route cancel through CANCEL_STATE so refund is output
                    r_next_state         = CANCEL_STATE;
                    r_next_return_change = r_stable_coin_value; // Refund all coins
                end
                else if (i_online_payment) begin
                    // Online payment: no change to return
                    r_next_state         = DISPENSE_AND_RETURN_STATE;
                    r_next_return_change = 7'd0;
                end
                else if (r_coin_stable && (r_stable_coin_value >= r_product_price)) begin
                    // FIX 2: Calculate change at transition time, not one cycle late
                    // FIX 5: Use debounced stable coin value
                    r_next_state         = DISPENSE_AND_RETURN_STATE;
                    r_next_return_change = r_stable_coin_value - r_product_price;
                end
                else begin
                    r_next_state = r_state; // Wait for sufficient payment
                end
            end

            // -----------------------------------------------------------------
            DISPENSE_AND_RETURN_STATE: begin
                // Change already computed at transition; just go back to idle
                r_next_state = IDLE_STATE;
            end

            // -----------------------------------------------------------------
            // FIX 1: New cancel state - outputs refund for one cycle then idles
            CANCEL_STATE: begin
                r_next_state = IDLE_STATE;
            end

            // -----------------------------------------------------------------
            default: begin
                r_next_state         = IDLE_STATE;
                r_next_product_price = 7'd0;
                r_next_return_change = 7'd0;
            end

        endcase
    end

    // -------------------------------------------------------------------------
    // Output Logic
    // -------------------------------------------------------------------------

    // Current FSM state
    assign o_state = r_state;

    // Dispense only in DISPENSE_AND_RETURN_STATE (not on cancel)
    assign o_dispense_product = (r_state == DISPENSE_AND_RETURN_STATE) ? 1'b1 : 1'b0;

    // FIX 1: Return change is valid in both dispense AND cancel states
    assign o_return_change = ((r_state == DISPENSE_AND_RETURN_STATE) ||
                              (r_state == CANCEL_STATE))
                             ? r_return_change : 7'd0; // FIX 4: 7'd0 not 1'b0

    // FIX 3: Show price during all selection states, not just during dispense
    assign o_product_price = ((r_state == PEN_SELECTION_STATE)           ||
                              (r_state == NOTEBOOK_SELECTION_STATE)      ||
                              (r_state == COKE_SELECTION_STATE)          ||
                              (r_state == LAYS_SELECTION_STATE)          ||
                              (r_state == WATER_BOTTLE_SELECTION_STATE)  ||
                              (r_state == DISPENSE_AND_RETURN_STATE))
                             ? r_product_price : 7'd0; // FIX 4: 7'd0 not 1'b0

endmodule