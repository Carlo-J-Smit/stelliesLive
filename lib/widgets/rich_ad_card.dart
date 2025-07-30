import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class HeroNativeAdCard extends StatefulWidget {
  const HeroNativeAdCard({super.key});

  @override
  State<HeroNativeAdCard> createState() => _HeroNativeAdCardState();
}

class _HeroNativeAdCardState extends State<HeroNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110', // ✅ Replace with YOUR production ID
      factoryId: 'listTile', // Use the upgraded layout with image
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
          debugPrint('✅ Hero Native Ad Loaded');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _isFailed = true);
          debugPrint('❌ Hero Native Ad Failed: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFailed) return const SizedBox.shrink();
    if (!_isLoaded) return const SizedBox(height: 220); // Placeholder space

    return Container(
      margin: const EdgeInsets.all(16),
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
