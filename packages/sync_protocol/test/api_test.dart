import 'dart:convert';

import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

/// [value] after a trip through JSON text, as it crosses the network.
Map<String, Object?> wire(Map<String, Object?> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

void main() {
  final event = EventEnvelope.next(
    eventId: uuidV7(),
    matchId: 'm',
    seq: 0,
    type: EventTypes.matchCreated,
    actor: Actors.user,
    payload: const {'stake': 100},
    clientTime: DateTime.utc(2026, 10, 9),
    userId: 'u',
    deviceId: 'd',
    gameId: 'twentynine',
    rulesVersion: 1,
    appVersion: 'test',
    prevHash: genesisHash,
  );

  test('an upload keeps its events exactly, hashes included', () {
    final batch = UploadBatch.fromJson(
      wire(UploadBatch(matchId: 'm', events: [event]).toJson()),
    );
    expect(batch.matchId, 'm');
    expect(batch.events.single.hash, event.hash);
    expect(verifyChain(batch.events), isNull);
  });

  test('acknowledgements, wallets and merges survive the trip', () {
    const wallet = WalletState(
      balance: 3500,
      credited: [CoinCredit(CoinReason.googleSignupBonus, 2500)],
    );
    final ack = SyncAck.fromJson(
      wire(
        const SyncAck(
          matchId: 'm',
          ackedSeq: 41,
          status: MatchSyncStatus.rejected,
          reason: 'illegal action',
          wallet: wallet,
        ).toJson(),
      ),
    );
    expect(
      (ack.matchId, ack.ackedSeq, ack.status, ack.reason),
      ('m', 41, MatchSyncStatus.rejected, 'illegal action'),
    );
    expect(ack.wallet.balance, 3500);
    expect(ack.wallet.credited, wallet.credited);

    final open = SyncAck.fromJson(
      wire(
        const SyncAck(
          matchId: 'm',
          ackedSeq: -1,
          status: MatchSyncStatus.open,
          wallet: WalletState(balance: 0),
        ).toJson(),
      ),
    );
    expect(open.reason, isNull);

    final merged = MergeResult.fromJson(
      wire(const MergeResult(coinsMoved: 300, wallet: wallet).toJson()),
    );
    expect((merged.coinsMoved, merged.wallet.balance), (300, 3500));
    expect(
      MergeRequest.fromJson(
        wire(const MergeRequest(guestAccessToken: 't').toJson()),
      ).guestAccessToken,
      't',
    );
  });

  test('malformed messages are refused', () {
    expect(
      () => UploadBatch.fromJson(const {'matchId': 'm'}),
      throwsFormatException,
    );
    expect(
      () => UploadBatch.fromJson(const {
        'matchId': 'm',
        'events': [1],
      }),
      throwsFormatException,
    );
    expect(
      () => WalletState.fromJson(const {'balance': '1'}),
      throwsFormatException,
    );
    expect(() => MergeRequest.fromJson(const {}), throwsFormatException);
  });

  test('a batch holds at most 200 events (AGENTS.md §9)', () {
    expect(ServerApi.maxBatchEvents, 200);
  });
}
