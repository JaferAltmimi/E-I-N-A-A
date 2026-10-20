import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _pages = <_OnboardingData>[
    _OnboardingData(
      eyebrow: 'أهلًا بك في',
      title: 'مِشكاة',
      description:
          'رفيقك اليومي إلى نور القرآن، وسكينة الذكر، وطمأنينة الصلاة.',
      kind: _VisualKind.lantern,
    ),
    _OnboardingData(
      eyebrow: 'القرآن الكريم',
      title: 'وردٌ يبقى قريبًا',
      description: 'اقرأ واستمع واحفظ، وتابع ختمتك بخطوات هادئة تناسب يومك.',
      kind: _VisualKind.quran,
    ),
    _OnboardingData(
      eyebrow: 'يومك مع الله',
      title: 'لا تفُتك لحظة ذكر',
      description:
          'مواقيت دقيقة، قبلة واضحة، وأذكار ترافق صباحك ومساءك حتى دون إنترنت.',
      kind: _VisualKind.prayer,
    ),
    _OnboardingData(
      eyebrow: 'مساحتك الخاصة',
      title: 'عبادة بهدوء، كل يوم',
      description:
          'كل ما تحتاجه في مكان واحد، بتجربة بسيطة تحترم تركيزك وخصوصيتك.',
      kind: _VisualKind.journey,
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    HapticFeedback.lightImpact();
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _next() async {
    if (_isLast) return _finish();
    HapticFeedback.selectionClick();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 430),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.mishkat;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF13251F), Color(0xFF0E1714)]
                : _index == 0
                ? const [Color(0xFFEAF3F0), Color(0xFFF9FBFA)]
                : const [Color(0xFFF3F7F6), Color(0xFFFAFCFB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    const _CompactBrand(),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _isLast,
                        child: TextButton(
                          key: const ValueKey('onboarding-skip'),
                          onPressed: _finish,
                          child: Text(
                            'تخطّي',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('onboarding-pages'),
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) => _OnboardingSlide(
                    data: _pages[index],
                    isActive: index == _index,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          key: ValueKey('onboarding-dot-$index'),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          width: index == _index ? 28 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _index
                                ? colors.primary
                                : colors.border,
                            borderRadius: MishkatRadius.brPill,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        key: const ValueKey('onboarding-primary-action'),
                        onPressed: _finishing ? null : _next,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _finishing
                              ? const SizedBox.square(
                                  key: ValueKey('finishing'),
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  key: ValueKey(_isLast),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_isLast ? 'ابدأ رحلتك' : 'التالي'),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _isLast
                                          ? Icons.auto_awesome_rounded
                                          : Icons.arrow_back_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLast
                          ? 'يمكنك تخصيص كل شيء لاحقًا من الإعدادات'
                          : 'اسحب لاكتشاف المزيد',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BrandMark(size: 25),
      const SizedBox(width: 8),
      Text(
        'مِشكاة',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.3),
      ),
    ],
  );
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data, required this.isActive});

  final _OnboardingData data;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;
    return Semantics(
      namesRoute: true,
      label: '${data.title}. ${data.description}',
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, compact ? 8 : 20, 24, 0),
        child: Column(
          children: [
            Expanded(
              flex: compact ? 5 : 6,
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  scale: isActive ? 1 : .92,
                  child: _OnboardingVisual(kind: data.kind),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.eyebrow,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.mishkat.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: compact ? 28 : 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                data.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.mishkat.textSecondary,
                  height: 1.75,
                ),
              ),
            ),
            if (data.kind == _VisualKind.lantern) ...[
              const SizedBox(height: 14),
              Text(
                '﴿ اللَّهُ نُورُ السَّمَاوَاتِ وَالْأَرْضِ ۚ\nمَثَلُ نُورِهِ كَمِشْكَاةٍ فِيهَا مِصْبَاحٌ ﴾',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mishkat.primaryDark,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'سورة النور • ٣٥',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            SizedBox(height: compact ? 8 : 18),
          ],
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({required this.kind});

  final _VisualKind kind;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final dimension = math.min(shortest * .68, 270.0);
    return SizedBox.square(
      dimension: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: dimension * .86,
            height: dimension * .86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.mishkat.primarySoft.withValues(alpha: .72),
            ),
          ),
          CustomPaint(
            size: Size.square(dimension),
            painter: _OrbitPainter(
              color: context.mishkat.primary.withValues(alpha: .18),
            ),
          ),
          switch (kind) {
            _VisualKind.lantern => _LanternVisual(dimension: dimension),
            _VisualKind.quran => _QuranVisual(dimension: dimension),
            _VisualKind.prayer => _PrayerVisual(dimension: dimension),
            _VisualKind.journey => _JourneyVisual(dimension: dimension),
          },
        ],
      ),
    );
  }
}

class _LanternVisual extends StatelessWidget {
  const _LanternVisual({required this.dimension});
  final double dimension;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: dimension * .46,
        height: dimension * .62,
        decoration: BoxDecoration(
          color: context.mishkat.surface.withValues(alpha: .82),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dimension),
            bottom: Radius.circular(dimension * .08),
          ),
          border: Border.all(color: context.mishkat.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: context.mishkat.gold.withValues(alpha: .20),
              blurRadius: 32,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
      Container(
        width: dimension * .09,
        height: dimension * .34,
        decoration: BoxDecoration(
          color: context.mishkat.gold,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.mishkat.gold.withValues(alpha: .55),
              blurRadius: 24,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
      Positioned(
        top: dimension * .11,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: dimension * .10,
          color: context.mishkat.gold,
        ),
      ),
    ],
  );
}

class _QuranVisual extends StatelessWidget {
  const _QuranVisual({required this.dimension});
  final double dimension;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Transform.rotate(
        angle: -.05,
        child: Container(
          width: dimension * .58,
          height: dimension * .48,
          padding: EdgeInsets.all(dimension * .055),
          decoration: BoxDecoration(
            color: context.mishkat.primaryDark,
            borderRadius: BorderRadius.circular(dimension * .07),
            boxShadow: MishkatShadows.elevated(context),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(dimension * .035),
              border: Border.all(
                color: context.mishkat.heroLabel.withValues(alpha: .75),
              ),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: dimension * .20,
              color: context.mishkat.heroLabel,
            ),
          ),
        ),
      ),
      _FloatingChip(
        alignment: const Alignment(.88, -.72),
        icon: Icons.headphones_rounded,
        label: 'استماع',
      ),
      _FloatingChip(
        alignment: const Alignment(-.88, .72),
        icon: Icons.bookmark_outline_rounded,
        label: 'متابعة',
      ),
    ],
  );
}

class _PrayerVisual extends StatelessWidget {
  const _PrayerVisual({required this.dimension});
  final double dimension;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: dimension * .59,
        padding: EdgeInsets.symmetric(
          horizontal: dimension * .07,
          vertical: dimension * .065,
        ),
        decoration: BoxDecoration(
          color: context.mishkat.surface,
          borderRadius: BorderRadius.circular(dimension * .09),
          border: Border.all(color: context.mishkat.borderSubtle),
          boxShadow: MishkatShadows.elevated(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nights_stay_rounded,
              color: context.mishkat.primary,
              size: dimension * .14,
            ),
            const SizedBox(height: 8),
            Text(
              'المغرب',
              style: TextStyle(
                color: context.mishkat.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '٦:١٨',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: context.mishkat.textPrimary,
                fontSize: dimension * .10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      _FloatingChip(
        alignment: const Alignment(.95, -.72),
        icon: Icons.explore_outlined,
        label: 'القبلة',
      ),
      _FloatingChip(
        alignment: const Alignment(-.94, .76),
        icon: Icons.notifications_none_rounded,
        label: 'تنبيه',
      ),
    ],
  );
}

class _JourneyVisual extends StatelessWidget {
  const _JourneyVisual({required this.dimension});
  final double dimension;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      SizedBox.square(
        dimension: dimension * .57,
        child: CircularProgressIndicator(
          value: .78,
          strokeWidth: dimension * .035,
          strokeCap: StrokeCap.round,
          backgroundColor: context.mishkat.surface,
          color: context.mishkat.primary,
        ),
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: dimension * .13,
            color: context.mishkat.gold,
          ),
          const SizedBox(height: 6),
          Text(
            'ورد اليوم',
            style: TextStyle(
              color: context.mishkat.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '٣ من ٤',
            style: TextStyle(
              fontSize: dimension * .075,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      _FloatingChip(
        alignment: const Alignment(.97, -.75),
        icon: Icons.done_rounded,
        label: 'ذكر',
      ),
      _FloatingChip(
        alignment: const Alignment(-.96, .76),
        icon: Icons.lock_outline_rounded,
        label: 'خصوصية',
      ),
    ],
  );
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.mishkat.surface,
        borderRadius: MishkatRadius.brPill,
        border: Border.all(color: context.mishkat.borderSubtle),
        boxShadow: MishkatShadows.subtle(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.mishkat.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * .96,
      height: size.height * .64,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.32);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawOval(rect, paint);
    canvas.restore();
    canvas.drawCircle(
      Offset(size.width * .88, size.height * .38),
      4,
      Paint()..color = color.withValues(alpha: .8),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.color != color;
}

enum _VisualKind { lantern, quran, prayer, journey }

class _OnboardingData {
  const _OnboardingData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.kind,
  });

  final String eyebrow;
  final String title;
  final String description;
  final _VisualKind kind;
}
