#import <Flutter/Flutter.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>


@interface FlutterLibepiccashPlugin : NSObject<FlutterPlugin>
@end

// NOTE: put the lines from the include here whenever new api functions are added.

/**
 * Cancel and destroy a listener via FFI.
 * This cancels the listener task and frees the associated handle memory.
 */
const char *_listener_cancel(void *handler);

/**
 * Check if the listener is still running via FFI.
 * Returns "true" if the listener is alive (task not completed), "false" if it has stopped.
 * Returns "false" if the handler is null.
 */
const char *_listener_is_running(void *handler);

/**
 * Get a new mnemonic.
 */
const char *get_mnemonic(void);

/**
 * Create a transaction via FFI.
 */
const char *rust_create_tx(const char *wallet,
                           const char *amount,
                           const char *to_address,
                           const char *secret_key_index,
                           const char *epicbox_config,
                           const char *confirmations,
                           const char *note,
                           const char *return_slate_flag);

/**
 * Delete a wallet via FFI.
 */
const char *rust_delete_wallet(const char *_wallet, const char *config);

/**
 * Start a listener via FFI.
 */
void *rust_epicbox_listener_start(const char *wallet, const char *epicbox_config);

/**
 * Get chain height via FFI.
 */
const char *rust_get_chain_height(const char *config);

/**
 * Validate an address.
 */
const char *rust_get_tx_fees(const char *wallet,
                             const char *c_amount,
                             const char *min_confirmations);

/**
 * Get a wallet address via FFI.
 */
const char *rust_get_wallet_address(const char *wallet,
                                    const char *index,
                                    const char *epicbox_config);

/**
 * Open a wallet via FFI.
 */
const char *rust_open_wallet(const char *config, const char *password);

/**
 * Recover a wallet from a mnemonic via FFI.
 */
const char *rust_recover_from_mnemonic(const char *config,
                                       const char *password,
                                       const char *mnemonic,
                                       const char *name);

/**
 * Cancel a transaction via FFI.
 */
const char *rust_tx_cancel(const char *wallet, const char *tx_id);

/**
 * Finalize a slate via FFI.
 *
 * This is step 3 of the 3-part transaction process for slates/slatepacks.
 * The original sender finalizes the transaction with the receiver's response
 * and broadcasts it to the network.
 */
const char *rust_tx_finalize(const char *wallet, const char *slate_json);

/**
 * Receive a slate via FFI.
 *
 * This is step 2 of the 3-part transaction process for slates/slatepacks.
 * The receiver opens an incoming slate, adds its output and partial signature,
 * then returns the updated slate.
 */
const char *rust_tx_receive(const char *wallet, const char *slate_json);

/**
 * Send a transaction via FFI.
 */
const char *rust_tx_send_http(const char *wallet,
                              const char *selection_strategy_is_use_all,
                              const char *minimum_confirmations,
                              const char *message,
                              const char *amount,
                              const char *address);

/**
 * Get transactions via FFI.
 */
const char *rust_txs_get(const char *wallet, const char *refresh_from_node);

/**
 * Validate an address via FFI.
 */
const char *rust_validate_address(const char *address);

/**
 * Get wallet balances via FFI.
 */
const char *rust_wallet_balances(const char *wallet,
                                 const char *refresh,
                                 const char *min_confirmations);

/**
 * Validate an address via FFI.
 */
const char *rust_wallet_scan_outputs(const char *wallet,
                                     const char *start_height,
                                     const char *number_of_blocks);

/**
 * Initialize a new wallet via FFI.
 */
const char *wallet_init(const char *config,
                        const char *mnemonic,
                        const char *password,
                        const char *name);
