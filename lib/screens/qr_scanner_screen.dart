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

    void submit() {
      final v = textController.text.trim();
      if (v.isEmpty) return;
      Navigator.pop(context);
      Navigator.pop(context, v);
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        backgroundColor: AppTheme.surfaceContainerOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.14),
                      ),
                      child: Icon(
                        Icons.keyboard_rounded,
                        color: cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Wpisz kod ręcznie',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Jeśli kod QR się nie skanuje, wprowadź jego numer poniżej.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: textController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: '1001',
                    hintStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHighOf(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 22,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Zatwierdź'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    textStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
