import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class NativeAdBanner extends StatefulWidget {
  final void Function(bool visible)? onVisibilityChanged;
  const NativeAdBanner({super.key, this.onVisibilityChanged});

  @override
  State<NativeAdBanner> createState() => _NativeAdBannerState();
}

class _NativeAdBannerState extends State<NativeAdBanner>
    with SingleTickerProviderStateMixin {
  final List<Widget> _adWidgets = [];
  int _currentIndex = 0;
  bool _visible = false;
  bool _dismissed = false;
  int _reloadCount = 0;
  Timer? _rotationTimer;

  static const int _maxReloads = 2;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  void _loadAds() {
    debugPrint('🧲 Loading ads...');
    for (int i = 0; i < 3; i++) {
      final nativeAd = NativeAd(
        adUnitId: 'ca-app-pub-3940256099942544/2247696110',
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('✅ Native ad $i loaded');
            setState(() {
              _adWidgets.add(AdWidget(ad: ad as NativeAd));
              if (!_visible && !_dismissed && _adWidgets.length == 1) {
                _startRotation();
              }
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint("❌ Native ad $i failed: $error. Loading fallback banner...");
            ad.dispose();
            _loadFallbackBanner(i);
          },
        ),
      );
      nativeAd.load();
    }
  }

  void _loadFallbackBanner(int index) {
    final banner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('🪃 Fallback banner $index loaded');
          setState(() {
            _adWidgets.add(AdWidget(ad: ad as BannerAd));
            if (!_visible && !_dismissed && _adWidgets.length == 1) {
              _startRotation();
            }
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner fallback $index failed: $error');
          ad.dispose();
        },
      ),
    );
    banner.load();
  }

  void _startRotation() {
    debugPrint("🔄 Starting ad rotation...");
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && !_dismissed) {
        setState(() {
          _visible = true;
        });
        widget.onVisibilityChanged?.call(true);
      }
    });

    widget.onVisibilityChanged?.call(true);

    _rotationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_dismissed || _adWidgets.isEmpty) {
        timer.cancel();
        debugPrint("🛑 Rotation stopped");
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % _adWidgets.length;
        debugPrint("➡️ Rotated to ad #$_currentIndex");
      });
    });
  }

  void _dismiss() {
    debugPrint("❌ Ad dismissed by user");
    _rotationTimer?.cancel();
    setState(() {
      _visible = false; // Triggers slide down
    });
    widget.onVisibilityChanged?.call(false);

    // After slide-down animation finishes
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _dismissed = true;
        });
      }
    });

    // Auto-reload after 3 minutes (max 2 reloads)
    if (_reloadCount < _maxReloads) {
      _reloadCount++;
      Future.delayed(const Duration(minutes: 1), () {
        if (mounted) {
          debugPrint("🔁 Reloading ads ($_reloadCount/$_maxReloads)");
          setState(() {
            _dismissed = false;
            _adWidgets.clear();
            _currentIndex = 0;
            _loadAds();
          });
        }
      });
    } else {
      debugPrint("🧯 Max ad reloads reached ($_reloadCount)");
    }
  }

  @override
  void dispose() {
    debugPrint("🧹 Disposing ad banner");
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adWidgets.isEmpty || _dismissed) return const SizedBox.shrink();

    final currentAd = _adWidgets[_currentIndex];

    return SafeArea(
      bottom: true,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 2400),
        offset: _visible ? Offset.zero : const Offset(0, 1),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 2400),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: Padding(
            key: ValueKey(_currentIndex),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // 👇 The ad box is now only 95% of the width
                Expanded(
                  flex: 85,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // AD CONTENT
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 100,
                            color: Colors.white,
                            child: currentAd,
                          ),
                        ),
                        // ❌ CLOSE BUTTON
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 15), // 👈 This shrinks the overall box from the right
              ],
            ),
          ),


        ),
      ),
    );
  }
}