import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../ad_config.dart';
import '../consent_service.dart';

class AdaptiveBannerSlot extends StatefulWidget {
  const AdaptiveBannerSlot({super.key, required this.consent});

  final ConsentService consent;

  @override
  State<AdaptiveBannerSlot> createState() => _AdaptiveBannerSlotState();
}

class _AdaptiveBannerSlotState extends State<AdaptiveBannerSlot> {
  BannerAd? _ad;
  AdSize? _size;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.consent.addListener(_onConsentChanged);
  }

  void _onConsentChanged() {
    if (!widget.consent.canRequestAds) {
      _ad?.dispose();
      _ad = null;
      _size = null;
      _loaded = false;
      if (mounted) setState(() {});
      return;
    }
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (_ad != null ||
        !widget.consent.canRequestAds ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _size = null;
          });
        },
      ),
    );
    setState(() {
      _ad = ad;
      _size = size;
    });
    await ad.load();
  }

  @override
  void dispose() {
    widget.consent.removeListener(_onConsentChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (!_loaded || ad == null || size == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.separator(context))),
        ),
        child: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
