import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/storage/sensitive_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fresh namespace does not import or delete old state', () async {
    SharedPreferences.setMockInitialValues({
      'userName': 'Mira',
      'points': 42,
      'purrfitLocalState': '{"onboarded":true,"points":42}',
      'darkMode': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final secure = _MemorySecureStore()
      ..values['purrfitLocalState'] = '{"onboarded":true,"points":42}';
    final store = SensitiveLocalStore(secureStore: secure);

    expect(SensitiveLocalStore.secureStateKey, 'purrfitJourneyState');
    expect(SensitiveLocalStore.schemaVersion, 3);
    expect(SensitiveLocalStore.stateKey(null), 'purrfitJourneyState');
    expect(
      SensitiveLocalStore.stateKey('user-a'),
      'purrfitJourneyState:user-a',
    );
    expect(await store.readAndMigrate(preferences), isEmpty);
    expect(secure.values.keys, {'purrfitLocalState'});
    expect(preferences.getString('userName'), 'Mira');
    expect(preferences.getInt('points'), 42);
    expect(
      preferences.getString('purrfitLocalState'),
      '{"onboarded":true,"points":42}',
    );
    expect(preferences.getBool('darkMode'), isTrue);
  });

  test('each account reads only its own fresh namespace', () async {
    SharedPreferences.setMockInitialValues({
      'purrfitLocalState': '{"ownerUserId":null,"points":7}',
    });
    final preferences = await SharedPreferences.getInstance();
    final secure = _MemorySecureStore()
      ..values['purrfitJourneyState:user-a'] = jsonEncode({
        'ownerUserId': 'user-a',
        'schemaVersion': 3,
        'points': 12,
      });
    final store = SensitiveLocalStore(secureStore: secure);

    expect(
      await store.readAndMigrate(preferences, ownerUserId: 'user-b'),
      isEmpty,
    );
    expect(
      await store.readAndMigrate(preferences, ownerUserId: 'user-a'),
      containsPair('points', 12),
    );
    expect(secure.values.containsKey('purrfitLocalState'), isFalse);
    expect(preferences.containsKey('purrfitLocalState'), isTrue);
  });

  test(
    'failed encrypted fallback write retains the new-namespace copy',
    () async {
      SharedPreferences.setMockInitialValues({
        'purrfitJourneyState': '{"points":42}',
        'purrfitLocalState': 'legacy',
        'points': 3,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = SensitiveLocalStore(
        secureStore: _MemorySecureStore(failWrites: true),
      );

      final state = await store.readAndMigrate(preferences);

      expect(state, containsPair('points', 42));
      expect(preferences.getString('purrfitJourneyState'), '{"points":42}');
      expect(preferences.getString('purrfitLocalState'), 'legacy');
      expect(preferences.getInt('points'), 3);
    },
  );

  test(
    'write and default clear preserve old namespace and flat preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'purrfitLocalState': 'old-local',
        'userName': 'Mira',
      });
      final preferences = await SharedPreferences.getInstance();
      final secure = _MemorySecureStore();
      final store = SensitiveLocalStore(secureStore: secure);

      expect(
        await store.write({
          'journey': {'completedCheckpoints': 1},
        }, preferences),
        isTrue,
      );
      expect(secure.values.containsKey('purrfitJourneyState'), isTrue);
      expect(preferences.getString('purrfitLocalState'), 'old-local');
      expect(preferences.getString('userName'), 'Mira');
      expect(await store.clear(preferences), isTrue);
      expect(secure.values.containsKey('purrfitJourneyState'), isFalse);
      expect(preferences.getString('purrfitLocalState'), 'old-local');
      expect(preferences.getString('userName'), 'Mira');
    },
  );

  test('explicit legacy clear removes old state only when requested', () async {
    SharedPreferences.setMockInitialValues({
      'purrfitLocalState': 'old-local',
      'userName': 'Mira',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SensitiveLocalStore(secureStore: _MemorySecureStore());

    expect(
      await store.clear(preferences, clearLegacyPreferences: true),
      isTrue,
    );
    expect(preferences.containsKey('purrfitLocalState'), isFalse);
    expect(preferences.containsKey('userName'), isFalse);
  });

  test(
    'corrupt stored JSON blocks writes instead of replacing progress',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final secure = _MemorySecureStore()
        ..values[SensitiveLocalStore.secureStateKey] = '{not-json';

      await expectLater(
        SensitiveLocalStore(secureStore: secure).readAndMigrate(preferences),
        throwsFormatException,
      );
      expect(secure.values[SensitiveLocalStore.secureStateKey], '{not-json');
      expect(decodeJsonObject('[1,2,3]'), isNull);
    },
  );
}

class _MemorySecureStore implements SecureKeyValueStore {
  _MemorySecureStore({this.failWrites = false});

  final bool failWrites;
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure storage unavailable');
    values[key] = value;
  }
}
