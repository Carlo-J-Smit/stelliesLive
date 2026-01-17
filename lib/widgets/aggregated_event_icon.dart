import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stellieslive/constants/colors.dart';

class AggregatedEventIcon extends StatelessWidget {
  final int count;
  final bool isDarkMode;
  final double size;

  const AggregatedEventIcon({
    Key? key,
    required this.count,
    this.isDarkMode = false,
    this.size = 50, // default diameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayText = count > 99 ? '99+' : count.toString();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isDarkMode
              ? [AppColors.primaryRed, AppColors.accent]
              : [AppColors.primaryRed, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.white,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: isDarkMode ? AppColors.darkInteract : AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//// Converts an aggregated event count into a custom BitmapDescriptor for Google Maps
Future<BitmapDescriptor> createAggregatedMarkerIcon({
  required int count,
  bool isDarkMode = false,
  double size = 120, // Higher size = better resolution
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final painter = _AggregatedIconPainter(
    count: count,
    isDarkMode: isDarkMode,
    size: size,
  );

  painter.paint(canvas, Size(size, size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(pngBytes);
}

/// CustomPainter that draws the aggregated marker with AppColors
class _AggregatedIconPainter extends CustomPainter {
  final int count;
  final bool isDarkMode;
  final double size;

  _AggregatedIconPainter({
    required this.count,
    required this.isDarkMode,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final displayText = count > 99 ? '99+' : count.toString();

    // Gradient background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: isDarkMode
          ? [AppColors.primaryRed, AppColors.accent]
          : [AppColors.primaryRed, AppColors.accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);

    // White border
    final borderPaint = Paint()
      ..color = isDarkMode ? AppColors.darkInteract : AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, borderPaint);

    // Count text
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: isDarkMode ? AppColors.white : AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: size.width * 0.4,
          shadows: [
            Shadow(
              color: Colors.black26,
              offset: const Offset(0, 2),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
