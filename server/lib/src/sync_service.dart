import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'replay.dart';
import 'store.dart';

/// A refusal, sent to the app as an HTTP status and an [ApiErrors] code.
final class ApiException implements Exception {
  /// Creates a refusal.
  const ApiException(this.status, this.code, this.message);

  /// The HTTP status.
  final int status;

  /// One of [ApiErrors], or another short code.
  final String code;

  /// What went wrong, for developers. Never personal data.
  final String message;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// The game server's rules for uploads, coins and accounts
/// (AGENTS.md §9 to §11; docs/decisions.md D-029 to D-032).
final class SyncService {
  /// A service keeping its records in [store], checking logs with
  /// [replayers].
  SyncService({
    required this.store,
    Iterable<MatchReplayer> replayers = const [TwentyNineReplayer()],
  }) : _replayers = {for (final r in replayers) r.gameId: r};

  /// Where profiles, logs and the ledger are kept.
  final ServerStore store;

  final Map<String, MatchReplayer> _replayers;

  /// The coin reasons a guest's match play adds up from.
  static final Set<String> _playReasons = {
    CoinReason.entryFee.name,
    CoinReason.dealWon.name,
    CoinReason.matchWon.name,
    CoinReason.lossPenalty.name,
    CoinReason.quitRefund.name,
    CoinReason.tieRefund.name,
  };

  /// The hash kept of a Google account's subject ID, so the sign-up bonus is
  /// paid once per account without keeping the ID itself (D-032).
  static String subjectHash(String provider, String subject) =>
      sha256.convert(utf8.encode('cardgames:$provider:$subject')).toString();

  /// The player's coins, crediting the starting gift and the Google sign-up
  /// bonus if they are due.
  Future<WalletState> wallet(AuthUser user) => store.transaction([user.id], (
    tx,
  ) async {
    final credited = await _settle(tx, user);
    return WalletState(balance: await tx.balance(user.id), credited: credited);
  });

  /// Takes one batch of a match's events (AGENTS.md §9): ignores what is
  /// already held, waits for missing events, checks the chain and replays
  /// the match. A complete, valid match is credited once, when the earlier
  /// matches of its game are accepted too (AGENTS.md §6.13). A batch with
  /// nothing new makes the server look at a waiting match again.
  Future<SyncAck> upload(AuthUser user, UploadBatch batch) async {
    final events = batch.events;
    if (events.isEmpty || events.length > ServerApi.maxBatchEvents) {
      throw const ApiException(
        400,
        ApiErrors.badRequest,
        'a batch holds 1 to ${ServerApi.maxBatchEvents} events',
      );
    }
    for (final (i, event) in events.indexed) {
      // The database keys these by UUID; anything else is malformed.
      if (!isUuid(event.matchId) ||
          !isUuid(event.userId) ||
          !isUuid(event.deviceId)) {
        throw const ApiException(
          400,
          ApiErrors.badRequest,
          'match, profile and device IDs must be UUIDs',
        );
      }
      if (event.matchId != batch.matchId) {
        throw const ApiException(
          400,
          ApiErrors.badRequest,
          'an event belongs to another match',
        );
      }
      if (i > 0 && event.seq != events[i - 1].seq + 1) {
        throw const ApiException(
          400,
          ApiErrors.badRequest,
          'the events of a batch must be consecutive',
        );
      }
    }
    return store.transaction([user.id], (tx) async {
      final credited = await _settle(tx, user);
      Future<SyncAck> ack(StoredMatch? match) async => SyncAck(
        matchId: batch.matchId,
        ackedSeq: match?.lastSeq ?? -1,
        status: match?.status ?? MatchSyncStatus.open,
        reason: match?.reason,
        wallet: WalletState(
          balance: await tx.balance(user.id),
          credited: credited,
        ),
      );

      var match = await tx.match(batch.matchId);
      if (match != null && match.userId != user.id) {
        throw const ApiException(
          403,
          ApiErrors.notYours,
          'the match belongs to another account',
        );
      }
      if (match != null && match.status != MatchSyncStatus.open) {
        return ack(match);
      }
      final expected = (match?.lastSeq ?? -1) + 1;
      final held = match == null
          ? const <EventEnvelope>[]
          : await tx.events(batch.matchId);
      // Events already held must be the same events: a retry, or a batch
      // sent twice.
      for (final event in events.where((e) => e.seq < expected)) {
        if (event.seq >= held.length || held[event.seq].hash != event.hash) {
          return ack(
            await _reject(
              tx,
              match,
              user,
              event,
              'event ${event.seq} differs from the one uploaded before',
            ),
          );
        }
      }
      final fresh = [
        for (final event in events)
          if (event.seq >= expected) event,
      ];
      // A later batch that arrived first: the answer tells the app where to
      // resume.
      if (fresh.isNotEmpty && fresh.first.seq != expected) return ack(match);
      // Nothing new: a match that waits for an earlier one of its game may
      // be ready now.
      if (fresh.isEmpty) {
        return ack(
          match == null || held.isEmpty
              ? match
              : await _evaluate(tx, user, match, held),
        );
      }

      final first = held.isEmpty ? fresh.first : held.first;
      final replayer = _replayers[first.gameId];
      if (replayer == null ||
          !replayer.rulesVersions.contains(first.rulesVersion)) {
        throw ApiException(
          422,
          'unsupported_rules',
          'no rules for ${first.gameId} version ${first.rulesVersion}',
        );
      }
      final profileId = first.userId;
      final owner = await tx.profileOwner(profileId);
      if (owner == null) {
        await tx.bindProfile(
          profileId: profileId,
          userId: user.id,
          deviceId: first.deviceId,
        );
      } else if (owner != user.id) {
        throw const ApiException(
          403,
          ApiErrors.notYours,
          'the profile belongs to another account',
        );
      }
      match ??= StoredMatch(
        matchId: batch.matchId,
        userId: user.id,
        profileId: profileId,
        gameId: first.gameId,
        rulesVersion: first.rulesVersion,
        lastSeq: -1,
        lastHash: genesisHash,
        status: MatchSyncStatus.open,
      );
      for (final event in fresh) {
        if (event.gameId != match.gameId ||
            event.rulesVersion != match.rulesVersion) {
          return ack(
            await _reject(tx, match, user, event, 'the game or rules change'),
          );
        }
        if (await tx.hasEvent(event.eventId)) {
          return ack(
            await _reject(tx, match, user, event, 'an event ID is reused'),
          );
        }
      }
      final log = [...held, ...fresh];
      final broken = verifyChain(log);
      if (broken != null) {
        return ack(
          await _reject(
            tx,
            match,
            user,
            fresh.first,
            'broken hash chain: $broken',
          ),
        );
      }
      // The match's record comes first: its events refer to it.
      await tx.putMatch(match);
      await tx.addEvents(batch.matchId, user.id, fresh);
      final progressed = match.copyWith(
        lastSeq: log.last.seq,
        lastHash: log.last.hash,
      );
      return ack(await _evaluate(tx, user, progressed, log));
    });
  }

  /// Replays [match]'s [log] and checks its place in its game against the
  /// server's records of the game's earlier matches, never the device's
  /// word (AGENTS.md §6.13). A complete match whose earlier matches are
  /// accepted is credited; one whose earlier match has not arrived waits.
  Future<StoredMatch> _evaluate(
    StoreTransaction tx,
    AuthUser user,
    StoredMatch match,
    List<EventEnvelope> log,
  ) async {
    final outcome = _replayers[match.gameId]!.replay(log);
    var placed = match;
    var refusal = outcome is ReplayRejected ? outcome.reason : null;
    var waiting = false;
    final series = _seriesOf(log.first);
    if (series != null) {
      final holder = await tx.seriesMatch(series.id, series.match);
      if (holder != null && holder.matchId != match.matchId) {
        refusal ??= 'another match holds its place in the game';
      } else {
        final key = tableKeyOf(log.first.payload);
        placed = match.copyWith(
          seriesId: series.id,
          seriesMatch: series.match,
          tableKey: key,
        );
        if (refusal == null && series.match > 1) {
          final previous = await tx.seriesMatch(series.id, series.match - 1);
          if (previous == null || previous.status == MatchSyncStatus.open) {
            waiting = true;
          } else if (previous.status == MatchSyncStatus.rejected) {
            refusal = 'an earlier match of its game was rejected';
          } else if (previous.profileId != match.profileId) {
            refusal = 'an earlier match of its game is another profile\'s';
          } else if (previous.seriesContinues != true) {
            refusal = 'its game had already ended';
          } else if (previous.tableKey != key) {
            refusal = 'the table changed within its game';
          } else if (previous.recordAfter != series.record) {
            refusal = 'its match record is not the one the server counted';
          }
        }
      }
    }
    final StoredMatch result;
    if (refusal != null) {
      result = placed.copyWith(
        status: MatchSyncStatus.rejected,
        reason: refusal,
      );
    } else if (outcome is ReplayComplete && !waiting) {
      var total = 0;
      for (final entry in outcome.coins) {
        await tx.credit(
          userId: user.id,
          delta: entry.amount,
          reason: entry.reason.name,
          refId: entry.deal == null
              ? match.matchId
              : '${match.matchId}:${entry.deal}',
        );
        total += entry.amount;
      }
      result = placed.copyWith(
        status: MatchSyncStatus.accepted,
        coins: total,
        recordAfter: outcome.recordAfter,
        seriesContinues: outcome.continues,
      );
    } else {
      result = placed;
    }
    await tx.putMatch(result);
    return result;
  }

  /// The game [first] places its match in, or null if it names none.
  static SeriesRef? _seriesOf(EventEnvelope first) {
    if (first.type != EventTypes.matchCreated) return null;
    try {
      return SeriesRef.fromCreated(first.payload);
    } on FormatException {
      return null;
    }
  }

  /// Moves a guest's progress into [target], the account it signed in to
  /// (AGENTS.md §10). The target gains what the guest won in matches, never
  /// less than zero; the guest's starting gift stays behind, and its
  /// profiles and unfinished matches now belong to the target (D-032).
  Future<MergeResult> merge(AuthUser target, AuthUser guest) async {
    if (target.isAnonymous) {
      throw const ApiException(
        403,
        ApiErrors.needsSignIn,
        'only a signed-in account can take in a guest',
      );
    }
    if (!guest.isAnonymous || guest.id == target.id) {
      throw const ApiException(
        400,
        ApiErrors.badRequest,
        'the other account is not a guest',
      );
    }
    return store.transaction([target.id, guest.id], (tx) async {
      final done = await tx.mergeOf(guest.id);
      if (done != null && done.toUserId != target.id) {
        throw const ApiException(
          409,
          ApiErrors.mergedAccount,
          'the guest was merged into another account',
        );
      }
      final credited = await _settle(tx, target);
      var moved = done?.coins ?? 0;
      if (done == null) {
        final won = await tx.sumOf(guest.id, _playReasons);
        moved = math.max(0, won);
        final left = await tx.balance(guest.id);
        if (left != 0) {
          await tx.credit(
            userId: guest.id,
            delta: -left,
            reason: CoinReason.mergedOut.name,
            refId: target.id,
          );
        }
        if (moved > 0) {
          await tx.credit(
            userId: target.id,
            delta: moved,
            reason: CoinReason.mergedIn.name,
            refId: guest.id,
          );
        }
        await tx.rebindProfiles(fromUserId: guest.id, toUserId: target.id);
        await tx.moveOpenMatches(fromUserId: guest.id, toUserId: target.id);
        await tx.recordMerge(
          fromUserId: guest.id,
          toUserId: target.id,
          coins: moved,
        );
      }
      return MergeResult(
        coinsMoved: moved,
        wallet: WalletState(
          balance: await tx.balance(target.id),
          credited: credited,
        ),
      );
    });
  }

  /// Refuses requests from merged guests, and credits what an account is
  /// due once: the starting gift, and the Google sign-up bonus the first
  /// time a Google account signs up (D-024).
  Future<List<CoinCredit>> _settle(StoreTransaction tx, AuthUser user) async {
    if (await tx.mergeOf(user.id) != null) {
      throw const ApiException(
        403,
        ApiErrors.mergedAccount,
        'this guest was merged into a signed-in account',
      );
    }
    final credited = <CoinCredit>[];
    if (await tx.credit(
      userId: user.id,
      delta: Economy.welcomeGift,
      reason: CoinReason.welcomeGift.name,
      refId: user.id,
    )) {
      credited.add(
        const CoinCredit(CoinReason.welcomeGift, Economy.welcomeGift),
      );
    }
    final google = user.googleSubject;
    if (google != null) {
      final hash = subjectHash('google', google);
      if (await tx.claimSignupBonus('google', hash) &&
          await tx.credit(
            userId: user.id,
            delta: Economy.googleSignupBonus,
            reason: CoinReason.googleSignupBonus.name,
            refId: hash,
          )) {
        credited.add(
          const CoinCredit(
            CoinReason.googleSignupBonus,
            Economy.googleSignupBonus,
          ),
        );
      }
    }
    return credited;
  }

  /// Marks [match] rejected at [event], storing nothing of the batch.
  Future<StoredMatch> _reject(
    StoreTransaction tx,
    StoredMatch? match,
    AuthUser user,
    EventEnvelope event,
    String reason,
  ) async {
    final rejected =
        (match ??
                StoredMatch(
                  matchId: event.matchId,
                  userId: user.id,
                  profileId: event.userId,
                  gameId: event.gameId,
                  rulesVersion: event.rulesVersion,
                  lastSeq: -1,
                  lastHash: genesisHash,
                  status: MatchSyncStatus.rejected,
                ))
            .copyWith(status: MatchSyncStatus.rejected, reason: reason);
    await tx.putMatch(rejected);
    return rejected;
  }
}
