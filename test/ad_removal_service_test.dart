import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:purrfit/purchases/ad_removal_service.dart';

class _FakePurchaseGateway implements PurchaseGateway {
  final StreamController<List<PurchaseDetails>> purchases =
      StreamController<List<PurchaseDetails>>.broadcast();
  int availabilityChecks = 0;
  int queries = 0;

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
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}

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
    fakePlatform.purchases.close();
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

    expect(service.storeReady, isTrue);
    expect(service.priceString, '€5,49');
    expect(fakePlatform.availabilityChecks, 1);
    expect(fakePlatform.queries, 1);
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
