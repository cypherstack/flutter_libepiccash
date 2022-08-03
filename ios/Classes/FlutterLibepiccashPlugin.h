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

const char *rust_wallet_balances(const char *config, const char *password, const char *refresh);

const char *rust_recover_from_mnemonic(const char *config,
                                       const char *password,
                                       const char *mnemonic,
                                       const char *name);

const char *rust_wallet_scan_outputs(const char *config,
                                     const char *password,
                                     const char *start_height);

const char *rust_create_tx(const char *config,
                           const char *password,
                           const char *amount,
                           const char *to_address,
                           const char *secret_key_index);

const char *rust_txs_get(const char *config,
                         const char *password,
                         const char *minimum_confirmations,
                         const char *refresh_from_node);

const char *rust_tx_cancel(const char *config, const char *password, const char *tx_id);

const char *rust_check_for_new_slates(const char *config,
                                      const char *password,
                                      const char *secret_key_index);

const char *rust_process_pending_slates(const char *config,
                                        const char *password,
                                        const char *secret_key_index,
                                        const char *slates);

const char *rust_get_chain_height(const char *config);

const char *rust_get_wallet_address(const char *config, const char *password, const char *index);

const char *rust_validate_address(const char *address);

const char *rust_get_tx_fees(const char *c_config, const char *c_password, const char *c_amount);
