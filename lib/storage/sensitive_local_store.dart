import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class PlatformSecureKeyValueStore implements SecureKeyValueStore {
  PlatformSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Encrypted persistence for the fresh journey namespace.
/// Older fitness and local-state namespaces are intentionally left untouched.
class SensitiveLocalStore {
  SensitiveLocalStore({
    SecureKeyValueStore? secureStore,
    this.usePlaintextForTesting = false,
  }) : _secureStore = secureStore ?? PlatformSecureKeyValueStore();

  static const secureStateKey = 'purrfitJourneyState';
  static const schemaVersion = 3;

  /// Guest and signed-in journey state use separate namespaces.
  static String stateKey(String? ownerUserId) =>
      ownerUserId == null ? secureStateKey : '$secureStateKey:$ownerUserId';

  static const legacyKeys = <String>{
    'onboarded',
    'avatarModel',
    'bodySlider',
    'goal',
    'daysPerWeek',
    'planId',
    'sessionId',
    'sessionIds',
    'workoutCursor',
    'exercise',
    'skips',
    'workoutSetIndex',
    'workoutRestUntil',
    'energy',
    'completedWorkouts',
    'points',
    'streak',
    'lastActive',
    'challengeDone',
    'installDate',
    'planStartDate',
    'bonusDoneKeys',
    'bonusUnlockDate',
    'bonusUnlockWorkout',
    'bonusUnlockConsumed',
    'startWeight',
    'goalWeight',
    'userName',
    'avatarChoice',
    'workoutDates',
    'caloriesByDate',
    'activityMinutesByDate',
    'napDays',
    'lastWorkoutKey',
    'streakDeadline',
    'napWeekKey',
    'reviewAsked',
    'reminderEnabled',
    'reminderHour',
    'reminderMinute',
    'safetyChecks',
    'events',
    'pendingWorkoutLogs',
    'activeWorkoutSeconds',
    'workoutStartedAt',
    'streakState',
  };

  final SecureKeyValueStore _secureStore;
  final bool usePlaintextForTesting;

  Future<Map<String, Object?>> readAndMigrate(
    SharedPreferences preferences, {
    String? ownerUserId,
  }) async {
    final key = stateKey(ownerUserId);
    final secureState = usePlaintextForTesting
        ? null
        : await _secureStore.read(key);
    final encoded = secureState ?? preferences.getString(key);
    if (encoded == null) return {};
    final state = decodeJsonObject(encoded);
    if (state == null) throw const FormatException('Unreadable saved journey');

    final storedOwner = state['ownerUserId'];
    final ownerMatches = ownerUserId == null
        ? storedOwner == null || storedOwner == ''
        : storedOwner == ownerUserId;
    if (!ownerMatches) {
      throw const FormatException('Saved journey owner mismatch');
    }

    final cleanState = Map<String, Object?>.from(state)..remove('events');
    final needsMetadata =
        cleanState['schemaVersion'] != schemaVersion ||
        cleanState['ownerUserId'] != ownerUserId ||
        state.containsKey('events');
    if (needsMetadata || (!usePlaintextForTesting && secureState == null)) {
      await write(cleanState, preferences, ownerUserId: ownerUserId);
    } else if (!usePlaintextForTesting) {
      await preferences.remove(key);
    }
    return cleanState;
  }

  Future<bool> write(
    Map<String, Object?> state,
    SharedPreferences preferences, {
    String? ownerUserId,
  }) async {
    final sanitized = <String, Object?>{
      ...state,
      'schemaVersion': schemaVersion,
      'ownerUserId': ownerUserId,
    }..remove('events');
    final encoded = jsonEncode(sanitized);
    final key = stateKey(ownerUserId);
    if (usePlaintextForTesting) {
      return preferences.setString(key, encoded);
    }
    try {
      await _secureStore.write(key, encoded);
      await preferences.remove(key);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Secure local state write failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> remove(
    String key,
    SharedPreferences preferences, {
    String? ownerUserId,
  }) async {
    final state = await readAndMigrate(preferences, ownerUserId: ownerUserId)
      ..remove(key);
    await write(state, preferences, ownerUserId: ownerUserId);
  }

  Future<bool> clear(
    SharedPreferences preferences, {
    String? ownerUserId,
    bool clearLegacyPreferences = false,
  }) async {
    final key = stateKey(ownerUserId);
    if (!usePlaintextForTesting) {
      try {
        await _secureStore.delete(key);
      } catch (error, stackTrace) {
        debugPrint('Secure local state delete failed: $error\n$stackTrace');
        return false;
      }
    }
    await preferences.remove(key);
    if (clearLegacyPreferences) {
      if (!usePlaintextForTesting) {
        try {
          await _secureStore.delete(
            ownerUserId == null
                ? 'purrfitLocalState'
                : 'purrfitLocalState:$ownerUserId',
          );
        } catch (error, stackTrace) {
          debugPrint(
            'Legacy secure local state delete failed: $error\n$stackTrace',
          );
          return false;
        }
      }
      await _removeLegacyKeys(preferences);
    }
    return true;
  }

  Future<void> _removeLegacyKeys(SharedPreferences preferences) async {
    for (final key in legacyKeys) {
      await preferences.remove(key);
    }
    await preferences.remove('purrfitLocalState');
  }
}

Map<String, Object?>? decodeJsonObject(String? encoded) {
  if (encoded == null || encoded.trim().isEmpty) return null;
  try {
    final value = jsonDecode(encoded);
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  } on FormatException {
    return null;
  }
}
