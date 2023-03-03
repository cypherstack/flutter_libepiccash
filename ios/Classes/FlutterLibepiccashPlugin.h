#import <Flutter/Flutter.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>


@interface FlutterLibepiccashPlugin : NSObject<FlutterPlugin>
@end

// NOTE: put the lines from the include here whenever new api functions are added.

const char *wallet_init(const char *config,
                        const char *mnemonic,
                        const char *password,
                        const char *name);

const char *get_mnemonic(void);

const char *rust_open_wallet(const char *config,
                const char *password);

const char *rust_wallet_balances(const char *wallet,
                                 const char *refresh,
                                 const char *min_confirmations);

const char *rust_recover_from_mnemonic(const char *config,
                                       const char *password,
                                       const char *mnemonic,
                                       const char *name);

const char *rust_wallet_scan_outputs(const char *wallet,
                                     const char *start_height,
                                     const char *number_of_blocks);

const char *rust_create_tx(const char *wallet,
                           const char *amount,
                           const char *to_address,
                           const char *secret_key_index,
                           const char *epicbox_config,
                           const char *min_confirmations);

const char *rust_txs_get(const char *wallet, const char *refresh_from_node);

const char *rust_tx_cancel(const char *wallet, const char *tx_id);

const char *rust_get_chain_height(const char *config);

const char *rust_delete_wallet(const char *wallet,
                               const char *epicbox_config);

const char *rust_get_wallet_address(const char *wallet,
                                    const char *index,
                                    const char *epicbox_config);

const char *rust_validate_address(const char *address);

const char *rust_get_tx_fees(const char *wallet,
                             const char *c_amount,
                             const char *min_confirmations);

const char *rust_tx_send_http(const char *wallet,
                              const char *selection_strategy_is_use_all,
                              const char *minimum_confirmations,
                              const char *message,
                              const char *amount,
                              const char *address);