import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_gradient.dart';

/// Reward screen with staff-confirmed redemption flow.
class RewardScreen extends StatefulWidget {
  const RewardScreen({
    super.key,
    required this.data,
    required this.completed,
    required this.isLocked,
    required this.onLock,
  });

  final AppData data;
  final List<String> completed;
  final bool isLocked;
  final Future<void> Function() onLock;

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  late bool _isLocked;

  int get _validCompleted => widget.completed
      .where((qr) => widget.data.checkpoints.any((c) => c.qrCode == qr))
      .length;

  bool get _canClaim => _validCompleted >= widget.data.goal && !_isLocked;

  String get _rewardPinDigits =>
      (widget.data.rewardPin ?? '').replaceAll(RegExp(r'\D'), '');

  bool get _hasConfiguredPin => _rewardPinDigits.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.isLocked;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, cs),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: _buildContent(context, cs),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.surfaceContainerLowestOf(context),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: cs.onSurface,
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Nagroda',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildProgressCircle(cs)
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 22),
        Text(
              _isLocked
                  ? 'Nagroda została wydana'
                  : _canClaim
                  ? 'Gratulacje, nagroda czeka!'
                  : 'Zbierz jeszcze pieczątki',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _isLocked
                    ? cs.primary
                    : _canClaim
                    ? cs.secondary
                    : cs.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            )
            .animate(delay: 150.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0, duration: 350.ms),
        const SizedBox(height: 14),
        Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighOf(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Html(
                data: widget.data.rewardDescription,
                onLinkTap: (url, _, _) {
                  if (url == null) return;
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    lineHeight: const LineHeight(1.7),
                    color: cs.onSurface,
                    textAlign: TextAlign.center,
                  ),
                  'p': Style(margin: Margins.only(bottom: 8)),
                  'a': Style(
                    color: cs.primary,
                    textDecoration: TextDecoration.underline,
                  ),
                },
              ),
            )
            .animate(delay: 200.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.08, end: 0, duration: 350.ms),
        const Spacer(),
        if (_isLocked)
          _buildRedeemedState(context, cs)
        else if (_canClaim)
          _buildClaimButton(context, cs),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProgressCircle(ColorScheme cs) {
    final progress = (widget.data.goal > 0)
        ? (_validCompleted / widget.data.goal).clamp(0.0, 1.0)
        : 0.0;
    final done = _validCompleted >= widget.data.goal || _isLocked;
    final remaining = (widget.data.goal - _validCompleted).clamp(
      0,
      widget.data.goal,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.brandCyan.withValues(alpha: 0.06),
            AppTheme.brandGreen.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandTeal.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 8,
            child: _GlowOrb(color: AppTheme.brandCyan.withValues(alpha: 0.18)),
          ),
          Positioned(
            right: 6,
            top: 12,
            child: _GlowOrb(
              size: 86,
              color: AppTheme.brandGreen.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 12,
            child: _GlowOrb(
              size: 112,
              color: AppTheme.brandAmber.withValues(alpha: 0.12),
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandGradientPill(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      'GRA TERENOWA',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 196,
                height: 196,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 196,
                      height: 196,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.brandCyan.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 182,
                      height: 182,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 14,
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    SizedBox(
                      width: 182,
                      height: 182,
                      child: ShaderMask(
                        shaderCallback: (rect) =>
                            AppTheme.brandGradient.createShader(rect),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => CircularProgressIndicator(
                            value: v,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 134,
                      height: 134,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.88),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandTeal.withValues(alpha: 0.10),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandGradientText(
                          '$_validCompleted',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '/ ${widget.data.goal} stref',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                done
                    ? 'Masz komplet pieczątek i możesz odebrać nagrodę'
                    : 'Do odblokowania zostało jeszcze $remaining ${_pluralStrefa(remaining)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                done
                    ? 'Pokaż ten ekran obsłudze punktu i potwierdź odbiór PIN-em.'
                    : 'Każda zeskanowana strefa przybliża Cię do juwenaliowego pakietu.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _handleClaim(context, cs),
          icon: const Icon(Icons.verified_rounded, size: 20),
          label: Text(
            _hasConfiguredPin ? 'Potwierdź odbiór nagrody' : 'Odbierz nagrodę',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: cs.secondary,
            foregroundColor: cs.onSecondary,
            textStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _hasConfiguredPin
              ? 'Pracownik punktu wpisze PIN ustawiony w CMS, aby potwierdzić wydanie nagrody.'
              : 'Jeśli chcesz, możesz później włączyć zabezpieczenie PIN-em z poziomu CMS.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRedeemedState(BuildContext context, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.16),
            cs.secondary.withValues(alpha: 0.20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.24),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.check_rounded, size: 34, color: cs.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Odbiór potwierdzony',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Nagroda została już oznaczona jako wydana. Jeśli to pomyłka, zmień status po stronie CMS lub wyczyść postęp w aplikacji.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleClaim(BuildContext context, ColorScheme cs) async {
    bool confirmed;

    if (_hasConfiguredPin) {
      confirmed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (_) => _RewardPinDialog(expectedPin: _rewardPinDigits),
          ) ??
          false;
    } else {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Odbierz nagrodę'),
              content: const Text(
                'Czy na pewno chcesz oznaczyć nagrodę jako wydaną?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.secondary,
                    foregroundColor: cs.onSecondary,
                  ),
                  child: const Text('Potwierdź'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await widget.onLock();
    if (!mounted) return;

    setState(() => _isLocked = true);
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nagroda została oznaczona jako wydana.')),
      );
  }

  String _pluralStrefa(int n) {
    if (n == 1) return 'strefę';
    if (n >= 2 && n <= 4) return 'strefy';
    return 'stref';
  }
}

class _RewardPinDialog extends StatefulWidget {
  const _RewardPinDialog({required this.expectedPin});

  final String expectedPin;

  @override
  State<_RewardPinDialog> createState() => _RewardPinDialogState();
}

class _RewardPinDialogState extends State<_RewardPinDialog> {
  String _value = '';
  bool _invalid = false;

  int get _pinLength => widget.expectedPin.length.clamp(4, 8);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final panel = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF151515)
        : const Color(0xFFF6F8FA);
    final keypad = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF232323)
        : const Color(0xFFFFFFFF);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weryfikacja odbioru',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pracownik stoiska wpisuje kod PIN, aby wydać nagrodę.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: BoxDecoration(
                color: keypad,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (index) {
                      final filled = index < _value.length;
                      final active =
                          index == _value.length && _value.length < _pinLength;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: filled
                              ? cs.primary.withValues(alpha: 0.12)
                              : AppTheme.surfaceContainerOf(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _invalid
                                ? cs.error
                                : active
                                ? cs.primary
                                : cs.outlineVariant.withValues(alpha: 0.55),
                            width: active || _invalid ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filled ? '•' : '',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_invalid) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Niepoprawny PIN. Spróbuj ponownie.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: cs.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...[
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', 'back'],
                  ].map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: row.map((key) {
                          if (key.isEmpty) {
                            return const Expanded(child: SizedBox(height: 56));
                          }

                          final isBack = key == 'back';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: _PinKeypadButton(
                                label: isBack ? null : key,
                                icon: isBack ? Icons.backspace_outlined : null,
                                onTap: () {
                                  if (isBack) {
                                    if (_value.isEmpty) return;
                                    setState(() {
                                      _value = _value.substring(
                                        0,
                                        _value.length - 1,
                                      );
                                      _invalid = false;
                                    });
                                    return;
                                  }

                                  if (_value.length >= _pinLength) return;
                                  setState(() {
                                    _value += key;
                                    _invalid = false;
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: _value.length == _pinLength ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Potwierdź'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_value == widget.expectedPin) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _invalid = true;
      _value = '';
    });
  }
}

class _PinKeypadButton extends StatelessWidget {
  const _PinKeypadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: cs.secondary, size: 20)
                : Text(
                    label!,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, this.size = 72});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.7,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}
