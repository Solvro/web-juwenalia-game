import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';

/// QR Scanner screen — camera-based, always dark UI.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;
  bool _flashOn = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    _hasScanned = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, code);
  }

  void _enterManual() {
    final textController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wpisz kod ręcznie'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Numer strefy (np. 1001)',
            hintStyle: GoogleFonts.plusJakartaSans(color: cs.onSurfaceVariant),
            filled: true,
            fillColor: AppTheme.surfaceContainerOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.spaceGrotesk(fontSize: 18),
          onSubmitted: (v) {
            Navigator.pop(context);
            Navigator.pop(context, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, textController.text.trim());
            },
            child: const Text('Zatwierdź'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scanner overlay is always dark regardless of system theme.
    const accentColor = Color(0xFF00A1E4);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Zeskanuj QR',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _flashOn = !_flashOn);
              _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _buildOverlay(context, accentColor),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, Color accent) {
    final size = MediaQuery.of(context).size;
    const cutout = 260.0;
    final top = size.height * 0.25;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: top + cutout,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: top,
          left: 0,
          width: (size.width - cutout) / 2,
          height: cutout,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: top,
          right: 0,
          width: (size.width - cutout) / 2,
          height: cutout,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          top: top,
          left: (size.width - cutout) / 2,
          child: _buildCornerMarkers(cutout, accent),
        ),
        Positioned(
          top: top + 4,
          left: (size.width - cutout) / 2 + 4,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) => Transform.translate(
              offset: Offset(0, (cutout - 8) * _pulseController.value),
              child: Container(
                width: cutout - 8,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, accent, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: top + cutout + 20,
          left: 0,
          right: 0,
          child: Text(
            'Skieruj aparat na kod QR strefy',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerMarkers(double size, Color color) {
    const thickness = 4.0;
    const length = 24.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: CustomPaint(
              size: const Size(length, length),
              painter: _CornerPainter(
                color: color,
                thickness: thickness,
                corner: 0,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(length, length),
              painter: _CornerPainter(
                color: color,
                thickness: thickness,
                corner: 1,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: CustomPaint(
              size: const Size(length, length),
              painter: _CornerPainter(
                color: color,
                thickness: thickness,
                corner: 2,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(length, length),
              painter: _CornerPainter(
                color: color,
                thickness: thickness,
                corner: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _enterManual,
              icon: const Icon(
                Icons.keyboard_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Wpisz kod',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38, width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final int corner;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.corner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (corner) {
      case 0:
        canvas.drawLine(Offset(0, size.height), const Offset(0, 0), paint);
        canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
      case 1:
        canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
        canvas.drawLine(
          Offset(size.width, 0),
          Offset(size.width, size.height),
          paint,
        );
      case 2:
        canvas.drawLine(const Offset(0, 0), Offset(0, size.height), paint);
        canvas.drawLine(
          Offset(0, size.height),
          Offset(size.width, size.height),
          paint,
        );
      case 3:
        canvas.drawLine(
          Offset(size.width, 0),
          Offset(size.width, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height),
          Offset(size.width, size.height),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
