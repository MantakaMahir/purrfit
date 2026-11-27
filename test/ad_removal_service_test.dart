import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:purrfit/purchases/ad_removal_service.dart';

class _FakePurchaseGateway implements PurchaseGateway {
  final StreamController<List<PurchaseDetails>> purchases =
      StreamController<List<PurchaseDetails>>.broadcast();
  int availabilityChecks = 0;
  int queries = 0;
  final completed = <PurchaseDetails>[];
  List<PurchaseDetails> restoreResults = [];
  bool failRestore = false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return true;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queries++;
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: identifiers.single,
          title: 'Remove ads',
          description: 'One-time purchase',
          price: '€5,49',
          rawPrice: 5.49,
          currencyCode: 'EUR',
          currencySymbol: '€',
        ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases() async {
    if (failRestore) throw StateError('Store offline');
    purchases.add(restoreResults);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}

PurchaseDetails _purchaseUpdate(PurchaseStatus status) => PurchaseDetails(
  productID: AdRemovalService.productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'store receipt',
    serverVerificationData: 'store purchase token',
    source: 'google_play',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakePurchaseGateway fakePlatform;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
    fakePlatform = _FakePurchaseGateway();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    return fakePlatform.purchases.close();
  });

  test('price uses a localized store price instead of a guessed amount', () {
    final service = AdRemovalService(billing: fakePlatform);
    addTearDown(service.dispose);

    expect(service.storeReady, isFalse);
    expect(service.priceString, 'See store price');
    expect(service.hasAdFreeAccess, isFalse);
    expect(service.loading, isFalse);
    expect(service.error, isNull);
  });

  test('billing stays inert off supported mobile platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final service = AdRemovalService(billing: fakePlatform);
    addTearDown(service.dispose);
    var notifications = 0;
    service.addListener(() => notifications++);

    await service.initialize();

    expect(service.available, isFalse);
    expect(await service.purchase(), isFalse);
    await service.restore();

    expect(service.hasAdFreeAccess, isFalse);
    expect(service.error, isNull);
    expect(notifications, 0);
    expect(fakePlatform.availabilityChecks, 0);
    expect(fakePlatform.queries, 0);
  });

  test('queries a localized price from the supported storefront', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = AdRemovalService(billing: fakePlatform);
    addTearDown(service.dispose);

    await service.initialize();
    await service.refresh();

    expect(service.storeReady, isTrue);
    expect(service.priceString, '€5,49');
    expect(fakePlatform.availabilityChecks, 1);
    expect(fakePlatform.queries, 1);
  });

  test(
    'approval grants access and pending purchases are never finished',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = AdRemovalService(billing: fakePlatform);
      addTearDown(service.dispose);
      await service.initialize();
      await service.refresh();

      final result = service.purchase();
      fakePlatform.purchases.add([_purchaseUpdate(PurchaseStatus.pending)]);
      expect(await result, isFalse);
      expect(service.pendingPurchase, isTrue);
      expect(service.hasAdFreeAccess, isFalse);
      expect(fakePlatform.completed, isEmpty);
      expect(await service.purchase(), isFalse);

      final approved = _purchaseUpdate(PurchaseStatus.purchased);
      fakePlatform.restoreResults = [approved];
      await service.restore();
      expect(service.pendingPurchase, isFalse);
      expect(service.hasAdFreeAccess, isTrue);
      expect(service.error, isNull);
      expect(fakePlatform.completed, [approved]);
      expect(
        (await SharedPreferences.getInstance()).getBool('adFreeOwned'),
        isTrue,
      );
    },
  );

  test(
    'Play restore cannot grant or finish a transaction still pending',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = AdRemovalService(billing: fakePlatform);
      addTearDown(service.dispose);
      await service.initialize();
      fakePlatform.restoreResults = GooglePlayPurchaseDetails.fromPurchase(
        PurchaseWrapper(
          orderId: '',
          packageName: 'com.purrfit.purrfit',
          purchaseTime: 0,
          purchaseToken: 'pending token',
          signature: '',
          products: [AdRemovalService.productId],
          isAutoRenewing: false,
          originalJson: '{}',
          isAcknowledged: false,
          purchaseState: PurchaseStateWrapper.pending,
        ),
      )..first.status = PurchaseStatus.restored;

      await service.restore();
      expect(service.pendingPurchase, isTrue);
      expect(service.hasAdFreeAccess, isFalse);
      expect(fakePlatform.completed, isEmpty);
    },
  );

  test('restore distinguishes an empty result from a store failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final service = AdRemovalService(billing: fakePlatform);
    addTearDown(service.dispose);
    await service.initialize();

    await service.restore();
    expect(service.error, contains('No ad-free purchase'));
    fakePlatform.failRestore = true;
    await service.restore();
    expect(service.error, contains('Could not restore purchases'));
  });

  test('billing is enabled for iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AdRemovalService.supported, isTrue);
    expect(AdRemovalService.storeName, 'App Store');
  });

  test('billing is enabled for Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AdRemovalService.supported, isTrue);
    expect(AdRemovalService.storeName, 'Google Play');
  });

  test('product identifier remains the same for both storefronts', () {
    // App Store Connect and Google Play Console must both use this ID.
    expect(AdRemovalService.productId, 'purrfit_ad_free');
  });
}
