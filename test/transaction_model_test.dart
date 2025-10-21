import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/models/transaction.dart';

void main() {
  test('Transaction.fromJson parses full object', () {
    final json = {
      'parent_key_id': 'key123',
      'id': 42,
      'tx_slate_id': 'slate-abc',
      'tx_type': 'TxSent',
      'creation_ts': '2024-10-01T00:00:00Z',
      'confirmation_ts': '2024-10-01T00:01:00Z',
      'confirmed': true,
      'num_inputs': 1,
      'num_outputs': 2,
      'amount_credited': '1000',
      'amount_debited': '1100',
      'fee': '100',
      'ttl_cutoff_height': '12345',
      'messages': {
        'messages': [
          {
            'id': 'm1',
            'public_key': 'pk1',
            'message': 'hi',
            'message_sig': 'sig',
          }
        ]
      },
      'stored_tx': 'stored',
      'kernel_excess': 'excess',
      'kernel_lookup_min_height': 10,
      'payment_proof': 'proof',
    };

    final tx = Transaction.fromJson(json);
    expect(tx.parentKeyId, 'key123');
    expect(tx.id, 42);
    expect(tx.txSlateId, 'slate-abc');
    expect(tx.txType, TransactionType.TxSent);
    expect(tx.creationTs, '2024-10-01T00:00:00Z');
    expect(tx.confirmationTs, '2024-10-01T00:01:00Z');
    expect(tx.confirmed, true);
    expect(tx.numInputs, 1);
    expect(tx.numOutputs, 2);
    expect(tx.amountCredited, '1000');
    expect(tx.amountDebited, '1100');
    expect(tx.fee, '100');
    expect(tx.ttlCutoffHeight, '12345');
    expect(tx.messages?.messages.length, 1);
    expect(tx.storedTx, 'stored');
    expect(tx.kernelExcess, 'excess');
    expect(tx.kernelLookupMinHeight, 10);
    expect(tx.paymentProof, 'proof');
  });

  test('Transaction.fromJson handles unknown tx_type', () {
    final json = {
      'parent_key_id': 'key',
      'id': '7', // test with string id to hit parsing path
      'tx_type': 'NotARealType',
      'creation_ts': 'ts',
      'confirmation_ts': 'ts2',
      'confirmed': 'false',
      'num_inputs': '0',
      'num_outputs': '0',
      'amount_credited': '0',
      'amount_debited': '0',
    };

    final tx = Transaction.fromJson(json);
    expect(tx.txType, TransactionType.Unknown);
    expect(tx.id, 7);
  });
}

