package com.stellieslive.app


import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import android.util.Log
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryExample(private val inflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = inflater.inflate(R.layout.native_ad_layout, null) as NativeAdView

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView.text = nativeAd.body
        adView.bodyView = bodyView

        // Icon
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView = iconView
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }
        

        adView.setNativeAd(nativeAd)
        Log.d("AdDebug", "Ad size: width=${adView.measuredWidth}, height=${adView.measuredHeight}")

        return adView
    }
}

