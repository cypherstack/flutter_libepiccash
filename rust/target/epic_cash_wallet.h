#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Initialize a new wallet via FFI.
 */
const char *wallet_init(const char *config,
                        const char *mnemonic,
                        const char *password,
                        const char *name);

/**
 * Get a new mnemonic.
 */
const char *get_mnemonic(void);

/**
 * Open a wallet via FFI.
 */
const char *rust_open_wallet(const char *config, const char *password);

/**
 * Get wallet balances via FFI.
 */
const char *rust_wallet_balances(const char *wallet,
                                 const char *refresh,
                                 const char *min_confirmations);

/**
 * Recover a wallet from a mnemonic via FFI.
 */
const char *rust_recover_from_mnemonic(const char *config,
                                       const char *password,
                                       const char *mnemonic,
                                       const char *name);

/**
 * Validate an address via FFI.
 */
const char *rust_wallet_scan_outputs(const char *wallet,
                                     const char *start_height,
                                     const char *number_of_blocks);

/**
 * Create a transaction via FFI.
 */
const char *rust_create_tx(const char *wallet,
                           const char *amount,
                           const char *to_address,
                           const char *secret_key_index,
                           const char *epicbox_config,
                           const char *confirmations,
                           const char *note);

/**
 * Get transactions via FFI.
 */
const char *rust_txs_get(const char *wallet, const char *refresh_from_node);

/**
 * Cancel a transaction via FFI.
 */
const char *rust_tx_cancel(const char *wallet, const char *tx_id);

/**
 * Get chain height via FFI.
 */
const char *rust_get_chain_height(const char *config);

/**
 * Delete a wallet via FFI.
 */
const char *rust_delete_wallet(const char *_wallet, const char *config);

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
 * Get a wallet address via FFI.
 */
const char *rust_get_wallet_address(const char *wallet,
                                    const char *index,
                                    const char *epicbox_config);

/**
 * Validate an address via FFI.
 */
const char *rust_validate_address(const char *address);

/**
 * Validate an address.
 */
const char *rust_get_tx_fees(const char *wallet,
                             const char *c_amount,
                             const char *min_confirmations);

/**
 * Start a listener via FFI.
 */
void *rust_epicbox_listener_start(const char *wallet, const char *epicbox_config);

/**
 * Cancel a listener via FFI.
 */
const char *_listener_cancel(void *handler);
