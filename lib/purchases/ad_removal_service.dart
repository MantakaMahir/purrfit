import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart'
    show InAppPurchasePlatform;
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
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase is GooglePlayPurchaseDetails) {
      // The public cross-platform wrapper discards Play's acknowledgement result.
      final platform =
          InAppPurchasePlatform.instance as InAppPurchaseAndroidPlatform;
      final result = await platform.completePurchase(purchase);
      if (result.responseCode != BillingResponse.ok) {
        throw StateError('Play acknowledgement failed: ${result.responseCode}');
      }
      return;
    }
    await _billing.completePurchase(purchase);
  }
}

/// Direct Apple App Store / Google Play Billing for the single no-ads product.
///
/// There is no backend and no third-party billing service. The purchase is a
/// store non-consumable, cached on the device and restored from the active
/// storefront when the user taps Restore purchases.
class AdRemovalService extends ChangeNotifier {
  static const productId = _productId;
  static const _storeTimeout = Duration(seconds: 15);

  AdRemovalService({PurchaseGateway? billing})
    : _billing = billing ?? _StorePurchaseGateway(InAppPurchase.instance);

  final PurchaseGateway _billing;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _product;
  bool _adFree = false;
  bool _querying = false;
  bool _disposed = false;
  bool _pendingPurchase = false;
  Future<void>? _initialization;
  Future<void>? _productQuery;
  Future<void> _purchaseUpdates = Future.value();
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
  bool get loading => _purchaseWaiter != null || _restoreWaiter != null;
  bool get pendingPurchase => _pendingPurchase;
  bool get querying => _querying;
  bool get storeReady => _product != null;
  String? get error => _error;
  String get priceString => _product?.price ?? 'See store price';

  Future<void> initialize() {
    if (!available || _disposed) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _adFree = prefs.getBool(_ownedKey) ?? false;
    } catch (error) {
      debugPrint('[billing] could not read cached purchase: $error');
    }
    if (_disposed) return;
    _purchaseSubscription = _billing.purchaseStream.listen(
      (purchases) {
        _purchaseUpdates = _purchaseUpdates.then(
          (_) => _onPurchases(purchases),
        );
      },
      onError: (Object error) {
        _error = '$storeName is unavailable right now.';
        debugPrint('[billing] purchase stream failed: $error');
        _finishWaiters(false);
        _notify();
      },
    );
    _notify();
  }

  Future<void> refresh() {
    if (!available || _disposed || loading) return Future.value();
    return _productQuery ??= _queryProduct();
  }

  Future<void> _queryProduct() async {
    _querying = true;
    _notify();
    try {
      final available = await _billing.isAvailable().timeout(_storeTimeout);
      if (!available) {
        _product = null;
        _error = '$storeName is unavailable right now.';
        return;
      }
      final response = await _billing
          .queryProductDetails({_productId})
          .timeout(_storeTimeout);
      _product = response.error == null
          ? response.productDetails
                .where((product) => product.id == _productId)
                .firstOrNull
          : null;
      _error = response.error != null
          ? '$storeName is unavailable right now.'
          : _product == null
          ? 'Ad removal is not available from $storeName yet.'
          : _pendingPurchase
          ? _error
          : null;
    } catch (error) {
      _product = null;
      _error = '$storeName is unavailable right now.';
      debugPrint('[billing] product query failed: $error');
    } finally {
      _productQuery = null;
      _querying = false;
      _notify();
    }
  }

  Future<bool> purchase() async {
    final product = _product;
    if (_adFree) return true;
    if (!available ||
        _disposed ||
        product == null ||
        loading ||
        _pendingPurchase) {
      return false;
    }
    _error = null;
    final waiter = Completer<bool>();
    _purchaseWaiter = waiter;
    _notify();
    try {
      // StoreKit 2 can wait for the purchase sheet to close before returning.
      const purchaseTimeout = Duration(minutes: 3);
      final started = await _billing
          .buyNonConsumable(
            purchaseParam: PurchaseParam(productDetails: product),
          )
          .timeout(purchaseTimeout);
      if (!started && !waiter.isCompleted) {
        _error = 'Purchase could not be started. Try again later.';
        return false;
      }
      return await waiter.future.timeout(
        purchaseTimeout,
        onTimeout: () {
          _error =
              'The store has not confirmed the purchase. Use Restore purchases to check again.';
          return false;
        },
      );
    } catch (error) {
      _error =
          'Could not confirm the purchase. Use Restore purchases to check again.';
      debugPrint('[billing] purchase failed to start: $error');
      return _adFree;
    } finally {
      _purchaseWaiter = null;
      _notify();
    }
  }

  Future<void> restore() async {
    if (!available || _disposed || loading) return;
    final waiter = Completer<bool>();
    _restoreWaiter = waiter;
    if (!_pendingPurchase) _error = null;
    _notify();
    try {
      await _billing.restorePurchases().timeout(_storeTimeout);
      final restored = await waiter.future.timeout(
        _storeTimeout,
        onTimeout: () {
          _error = 'The store has not confirmed the restore. Try again later.';
          return false;
        },
      );
      if (!restored && !_adFree && _error == null) {
        _error = 'No ad-free purchase was found for this $storeName account.';
      }
    } catch (error) {
      _error = 'Could not restore purchases from $storeName. Try again later.';
      debugPrint('[billing] restore failed to start: $error');
    } finally {
      _restoreWaiter = null;
      _notify();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    if (_disposed) return;
    if (purchases.isEmpty && _restoreWaiter != null) {
      _pendingPurchase = false;
      _error = null;
    }
    for (final purchase in purchases) {
      if (_disposed || purchase.productID != _productId) continue;
      final playState = purchase is GooglePlayPurchaseDetails
          ? purchase.billingClientPurchase.purchaseState
          : null;
      if (purchase.status == PurchaseStatus.pending ||
          playState == PurchaseStateWrapper.pending) {
        _pendingPurchase = true;
        _error =
            'Your purchase is pending approval. Ads turn off when $storeName completes it.';
        _finishWaiters(false);
        continue;
      }
      _pendingPurchase = false;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (playState == PurchaseStateWrapper.unspecified_state ||
              purchase.verificationData.serverVerificationData.isEmpty) {
            _error =
                '$storeName did not provide a purchase record. Try Restore purchases.';
            _finishWaiters(false);
            break;
          }
          try {
            await _cacheOwnership();
            _error = null;
          } catch (error) {
            _error =
                'Could not save your purchase on this device. Try Restore purchases.';
            debugPrint('[billing] could not cache purchase: $error');
            _finishWaiters(false);
            break;
          }
          await _completeIfNeeded(purchase);
          _finishWaiters(true);
        case PurchaseStatus.error:
          _error = 'Purchase could not be completed. Try again later.';
          if (playState == null) await _completeIfNeeded(purchase);
          _finishWaiters(false);
        case PurchaseStatus.canceled:
          _error = null;
          if (playState == null) await _completeIfNeeded(purchase);
          _finishWaiters(false);
        case PurchaseStatus.pending:
          break;
      }
    }
    if (_restoreWaiter case final waiter? when !waiter.isCompleted) {
      waiter.complete(_adFree);
    }
    _notify();
  }

  Future<void> _cacheOwnership() async {
    if (_adFree) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_ownedKey, true)) {
      throw StateError('Purchase cache write failed');
    }
    _adFree = true;
  }

  Future<void> _completeIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _billing.completePurchase(purchase).timeout(_storeTimeout);
    } catch (error) {
      _error =
          'The store could not finish the transaction. Use Restore purchases to retry.';
      debugPrint('[billing] completePurchase failed: $error');
    }
  }

  void _finishWaiters(bool value) {
    final purchase = _purchaseWaiter;
    if (purchase != null && !purchase.isCompleted) purchase.complete(value);
    final restore = _restoreWaiter;
    if (restore != null && !restore.isCompleted) restore.complete(value);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _finishWaiters(false);
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
