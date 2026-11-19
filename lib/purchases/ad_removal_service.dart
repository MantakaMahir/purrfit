import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productId = 'purrfit_ad_free';
const _ownedKey = 'adFreeOwned';

abstract interface class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class _StorePurchaseGateway implements PurchaseGateway {
  _StorePurchaseGateway(this._billing);

  final InAppPurchase _billing;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _billing.purchaseStream;

  @override
  Future<bool> isAvailable() => _billing.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _billing.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _billing.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _billing.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _billing.completePurchase(purchase);
}

/// Direct Apple App Store / Google Play Billing for the single no-ads product.
///
/// There is no backend and no third-party billing service. The purchase is a
/// store non-consumable, cached on the device and restored from the active
/// storefront when the user taps Restore purchases.
class AdRemovalService extends ChangeNotifier {
  static const productId = _productId;

  AdRemovalService({PurchaseGateway? billing})
    : _billing = billing ?? _StorePurchaseGateway(InAppPurchase.instance);

  final PurchaseGateway _billing;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _product;
  bool _adFree = false;
  bool _loading = false;
  bool _querying = false;
  bool _initialized = false;
  bool _disposed = false;
  String? _error;
  Completer<bool>? _purchaseWaiter;
  Completer<bool>? _restoreWaiter;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get storeName => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'App Store',
    TargetPlatform.android => 'Google Play',
    _ => 'app store',
  };

  bool get available => supported;
  bool get hasAdFreeAccess => _adFree;
  bool get loading => _loading;
  bool get querying => _querying;
  bool get storeReady => _product != null;
  String? get error => _error;
  String get priceString => _product?.price ?? 'See store price';

  Future<void> initialize() async {
    if (!available || _initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _adFree = prefs.getBool(_ownedKey) ?? false;
    _purchaseSubscription = _billing.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        _error = '$storeName is unavailable right now.';
        debugPrint('[billing] purchase stream failed: $error');
        _finishWaiters(false);
        _notify();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (!available) return;
    _querying = true;
    _notify();
    try {
      final available = await _billing.isAvailable();
      if (!available) {
        _product = null;
        _error = '$storeName is unavailable right now.';
        _querying = false;
        _notify();
        return;
      }
      final response = await _billing.queryProductDetails({_productId});
      _product = response.productDetails.isEmpty
          ? null
          : response.productDetails.first;
      _error = response.error != null
          ? '$storeName is unavailable right now.'
          : _product == null
          ? 'Ad removal is not available from $storeName yet.'
          : null;
    } catch (error) {
      _error = '$storeName is unavailable right now.';
      debugPrint('[billing] product query failed: $error');
    }
    _querying = false;
    _notify();
  }

  Future<bool> purchase() async {
    final product = _product;
    if (!available || product == null || _loading) return false;
    if (_adFree) return true;
    _loading = true;
    _error = null;
    _notify();
    final waiter = Completer<bool>();
    _purchaseWaiter = waiter;
    var started = false;
    try {
      started = await _billing.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (error) {
      debugPrint('[billing] purchase failed to start: $error');
    }
    if (!started) {
      if (_purchaseWaiter == waiter) _purchaseWaiter = null;
      _loading = false;
      _error = 'Purchase could not be started. Try again later.';
      _notify();
      return false;
    }
    final purchased = await waiter.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => false,
    );
    if (_purchaseWaiter == waiter) _purchaseWaiter = null;
    _loading = false;
    if (!purchased && _error == null) {
      _error = 'Purchase was not completed. Nothing was charged.';
    }
    _notify();
    return purchased;
  }

  Future<void> restore({bool silent = false}) async {
    if (!available || _restoreWaiter != null) return;
    if (!silent) {
      _loading = true;
      _error = null;
      _notify();
    }
    final waiter = Completer<bool>();
    _restoreWaiter = waiter;
    try {
      await _billing.restorePurchases();
    } catch (error) {
      debugPrint('[billing] restore failed to start: $error');
      if (!waiter.isCompleted) waiter.complete(false);
    }
    final restored = await waiter.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => _adFree,
    );
    if (_restoreWaiter == waiter) _restoreWaiter = null;
    if (!silent) {
      _loading = false;
      if (!restored && !_adFree) {
        _error = 'No ad-free purchase was found for this $storeName account.';
      }
      _notify();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == _productId) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            _error =
                'Your purchase is pending approval. Ads turn off when $storeName completes it.';
            _finishWaiters(false);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _setOwned(true);
            _finishWaiters(true);
          case PurchaseStatus.error:
            _error =
                purchase.error?.message ??
                'Purchase could not be completed. Try again later.';
            _finishWaiters(false);
          case PurchaseStatus.canceled:
            _error = null;
            _finishWaiters(false);
        }
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _billing.completePurchase(purchase);
        } catch (error) {
          debugPrint('[billing] completePurchase failed: $error');
        }
      }
    }
    _notify();
  }

  Future<void> _setOwned(bool value) async {
    _adFree = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ownedKey, value);
  }

  void _finishWaiters(bool value) {
    final purchase = _purchaseWaiter;
    _purchaseWaiter = null;
    if (purchase != null && !purchase.isCompleted) purchase.complete(value);
    final restore = _restoreWaiter;
    _restoreWaiter = null;
    if (restore != null && !restore.isCompleted) restore.complete(value);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
