import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'dart:async';

class ConsentService extends ChangeNotifier {
  var _canRequestAds = false;
  var _privacyOptionsRequired = false;
  var _initialized = false;

  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void> initialize() async {
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
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) _debug('consent form error: ${error.message}');
        });
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
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) _debug('privacy options error: ${error.message}');
      completer.complete();
    });
    await completer.future;
    await _refresh();
  }

  Future<void> _refresh() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    _privacyOptionsRequired =
        status == PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[ads] $message');
  }
}
