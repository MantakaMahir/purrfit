import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentService extends ChangeNotifier {
  var _canRequestAds = false;
  var _privacyOptionsRequired = false;
  var _initialized = false;
  var _disposed = false;

  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (_disposed) return;
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) _debug('consent form error: ${error.message}');
          });
        } catch (error) {
          _debug('Could not show the consent form: $error');
        }
        await _refresh();
      },
      (error) async {
        _debug('consent update error: ${error.message}');
        await _refresh();
      },
    );
  }

  Future<void> showPrivacyOptions() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final completer = Completer<void>();
      ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) _debug('privacy options error: ${error.message}');
        completer.complete();
      });
      await completer.future;
      await _refresh();
    } catch (error) {
      _debug('Could not show privacy options: $error');
    }
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      _canRequestAds = false;
      _debug('Could not read ad consent: $error');
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[ads] $message');
  }
}
