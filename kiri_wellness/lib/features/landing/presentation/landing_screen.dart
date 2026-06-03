// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/app_firebase.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/models/package_model.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
// Extracted from the official Kiri Wellness brand guide
const _kOlive      = Color(0xFF4A5240); // dark olive green
const _kTaupe      = Color(0xFF9B8B7A); // warm taupe
const _kLavender   = Color(0xFF9D87BC); // soft lavender/purple
const _kLavLight   = Color(0xFFD4C8E8); // lavender light
const _kCream      = Color(0xFFFBF8F3); // lighter warm cream background
const _kCreamDark  = Color(0xFFF3ECE2); // lighter cream for subtle contrast
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero ocupa 100% de ancho
            _HeroSection(onBook: () => context.go('/book')),
            // Contenido central limitado a 1440px
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1440 : double.infinity,
                ),
                child: const Column(
                  children: [
                    _BenefitsStrip(),
                    _ServicesSection(),
                    _PackagesSection(),
                    _AboutSection(),
                    _ContactSection(),
                  ],
                ),
              ),
            ),
            // Footer ocupa 100% de ancho
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final VoidCallback onBook;
  const _HeroSection({required this.onBook});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;
    final isTablet = width >= 700;

    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 680 : (isTablet ? 620 : 560),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/herokiri.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(color: _kCreamDark),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1E1A17).withValues(alpha: 0.66),
                  const Color(0xFF1E1A17).withValues(alpha: 0.38),
                  const Color(0xFF1E1A17).withValues(alpha: 0.58),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _HeroText(
                  onBook: onBook,
                  centered: true,
                  showLogo: false,
                  overImage: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final VoidCallback onBook;
  final bool centered;
  final bool showLogo;
  final bool overImage;
  const _HeroText({
    required this.onBook,
    this.centered = false,
    this.showLogo = true,
    this.overImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Brand logo — constrain by width for landscape PNG
        if (showLogo) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Image.asset(
              'assets/images/kiriwellness.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 36),
        ],
        Text(
          'Tu momento de bienestar\ncomienza con nosotros',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.cormorantGaramond(
            color: overImage ? Colors.white : _kOlive,
            fontSize: overImage ? (isWide ? 70 : 46) : (isWide ? 58 : 44),
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Masoterapia profesional para aliviar tensiones,\nrestaurar tu energía y cuidar tu cuerpo.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.lato(
            color: overImage ? Colors.white.withValues(alpha: 0.9) : _kTaupe,
            fontSize: overImage ? (isWide ? 41 / 2 : 34 / 2) : (isWide ? 22 : 18),
            height: overImage ? 1.45 : 1.6,
            fontWeight: overImage ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 44),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            ElevatedButton(
              onPressed: onBook,
              child: const Text('Reserva tu cita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: overImage ? _kLavender : _kOlive,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: overImage ? 34 : 28,
                  vertical: overImage ? 18 : 16,
                ),
                textStyle: GoogleFonts.lato(
                  fontSize: overImage ? 18 : 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: overImage ? 2 : 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Benefits strip
// ─────────────────────────────────────────────────────────────────────────────

class _BenefitsStrip extends StatelessWidget {
  const _BenefitsStrip();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final items = [
      (Icons.self_improvement_rounded, 'Alivio del estrés'),
      (Icons.healing_rounded, 'Reducción del dolor'),
      (Icons.favorite_border_rounded, 'Bienestar integral'),
      (Icons.schedule_rounded, 'Citas flexibles'),
    ];
    return Container(
      color: _kOlive,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 24,
        runSpacing: 12,
        children: items.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.$1, color: _kLavLight, size: 18),
            const SizedBox(width: 8),
            Text(e.$2, style: GoogleFonts.lato(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Services
// ─────────────────────────────────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  const _ServicesSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            tag: 'NUESTROS SERVICIOS',
            title: 'Terapias diseñadas\npara ti',
            subtitle: 'Cada sesión es personalizada para atender tus necesidades físicas y emocionales.',
          ),
          const SizedBox(height: 52),
          StreamBuilder<QuerySnapshot>(
            stream: AppFirebase.firestore
                .collection('services')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _kOlive));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
              final services = snap.data!.docs.map((d) => ServiceModel.fromFirestore(d)).toList();
              return LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 460 ? 2 : 1);
                return _ServiceGrid(services: services, columns: cols);
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  final List<ServiceModel> services;
  final int columns;
  const _ServiceGrid({required this.services, required this.columns});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: services.map((s) {
        final width = (MediaQuery.of(context).size.width -
                (MediaQuery.of(context).size.width >= 800 ? 160 : 48) -
                (columns - 1) * 20) /
            columns;
        final cardWidth = width.clamp(240, 400).toDouble();
        return SizedBox(
          width: cardWidth,
          child: _ServiceCard(service: s),
        );
      }).toList(),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _kLavender.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.spa_outlined, color: _kLavender, size: 24),
          ),
          const SizedBox(height: 16),
          Text(service.name,
              style: GoogleFonts.cormorantGaramond(fontSize: 20,
                  fontWeight: FontWeight.w700, color: _kOlive)),
          const SizedBox(height: 8),
          if (service.description.isNotEmpty) ...[
            Text(service.description,
                softWrap: true,
                style: GoogleFonts.lato(fontSize: 13, color: _kTaupe, height: 1.65)),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(icon: Icons.schedule_outlined, label: '${service.durationMinutes} min'),
            if (service.price > 0)
              _Chip(icon: Icons.payments_outlined,
                  label: service.price.toStringAsFixed(0)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Packages
// ─────────────────────────────────────────────────────────────────────────────

class _PackagesSection extends StatelessWidget {
  const _PackagesSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      width: double.infinity,
      color: _kCream,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            tag: 'PAQUETES',
            title: 'Ahorra más con\nnuestros paquetes',
            subtitle: 'Combina sesiones de diferentes terapias y obtén un precio especial.',
          ),
          const SizedBox(height: 52),
          StreamBuilder<QuerySnapshot>(
            stream: AppFirebase.firestore
                .collection('packages')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _kOlive));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
              final packages = snap.data!.docs.map((d) => PackageModel.fromFirestore(d)).toList();
              return Wrap(spacing: 20, runSpacing: 20,
                  children: packages.map((p) => _PackageLandingCard(pkg: p)).toList());
            },
          ),
        ],
      ),
    );
  }
}

class _PackageLandingCard extends StatelessWidget {
  final PackageModel pkg;
  const _PackageLandingCard({required this.pkg});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardWidth = (w >= 800
            ? (w - 160 - 40) / 3
            : (w >= 540 ? (w - 48 - 20) / 2 : w - 48))
        .clamp(260.0, 420.0);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kLavender.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard_outlined, color: _kLavender, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(pkg.name,
                style: GoogleFonts.cormorantGaramond(fontSize: 18,
                    fontWeight: FontWeight.w700, color: _kOlive))),
          ]),
          if (pkg.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(pkg.description,
                softWrap: true,
                style: GoogleFonts.lato(fontSize: 13, color: _kTaupe, height: 1.6)),
          ],
          const SizedBox(height: 16),
          ...pkg.services.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 15, color: _kOlive),
              const SizedBox(width: 8),
              Text('${s.sessionCount}× ${s.serviceName}',
                  style: GoogleFonts.lato(fontSize: 13, color: _kOlive)),
            ]),
          )),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _kCreamDark),
          const SizedBox(height: 16),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (pkg.discountPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kOlive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${pkg.discountPercent.toStringAsFixed(0)}% descuento',
                      style: GoogleFonts.lato(color: _kOlive,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 4),
                Text(pkg.price.toStringAsFixed(0),
                  style: GoogleFonts.cormorantGaramond(fontSize: 24,
                      fontWeight: FontWeight.bold, color: _kOlive)),
            ]),
            const Spacer(),
            if (pkg.validityDays > 0)
              _Chip(icon: Icons.calendar_today_outlined, label: '${pkg.validityDays} días'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _RequestPackageDialog(pkg: pkg),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kLavender,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.lato(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: const Text('Adquirir paquete'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About — Acerca de Nosotros / Historia del árbol Kiri
// ─────────────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Column(
      children: [
        // ── Historia del nombre ─────────────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 24, vertical: 88),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: _KiriStoryText()),
                    const SizedBox(width: 60),
                    Expanded(flex: 4, child: _KiriTreeIllustration()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KiriStoryText(),
                    const SizedBox(height: 40),
                    _KiriTreeIllustration(),
                  ],
                ),
        ),
        // ── Pilares de valor ────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: _kCream,
          padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 24, vertical: 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NUESTROS PILARES',
                  style: GoogleFonts.lato(
                      color: _kLavender,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 10),
              Text('Lo que nos define',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: _kOlive,
                      height: 1.2)),
              const SizedBox(height: 52),
              LayoutBuilder(builder: (ctx, constraints) {
                const pillars = [
                  _KiriValuePillar(
                      emoji: '🌱',
                      title: 'Crecimiento',
                      description:
                          'Cada sesión es un paso hacia tu mejor versión. Como el Kiri, tú también creces hacia la luz.'),
                  _KiriValuePillar(
                      emoji: '🌿',
                      title: 'Renovación',
                      description:
                          'Restauramos tu energía y devolvemos el equilibrio a tu cuerpo y tu mente.'),
                  _KiriValuePillar(
                      emoji: '🌳',
                      title: 'Arraigo',
                      description:
                          'Masoterapia con raíces profundas en técnicas probadas y atención completamente personalizada.'),
                  _KiriValuePillar(
                      emoji: '✨',
                      title: 'Ligereza',
                      description:
                          'Libera tensiones acumuladas y redescubre la ligereza de tu cuerpo y tu espíritu.'),
                ];
                final cols = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                final isDesktop = cols == 4;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: pillars.map((p) {
                    final w =
                        (constraints.maxWidth - (cols - 1) * 20) / cols;
                    return SizedBox(
                      width: w.clamp(200.0, 360.0),
                      height: isDesktop ? 290 : null,
                      child: p,
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _KiriStoryText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACERCA DE NOSOTROS',
            style: GoogleFonts.lato(
                color: _kLavender,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
        const SizedBox(height: 12),
        Text('¿Por qué Kiri Wellness?',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: _kOlive,
                height: 1.2)),
        const SizedBox(height: 20),
        Text(
          'El Kiri es uno de los árboles de crecimiento más rápido del mundo. '
          'Hunde sus raíces profundamente en la tierra, se renueva tras cualquier '
          'adversidad y purifica el aire a su alrededor con cada hoja.',
          style: GoogleFonts.lato(
              fontSize: 15,
              color: _kOlive,
              height: 1.75,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'En Kiri Wellness esa misma energía nos inspira: creemos en tu capacidad '
          'de crecer, renovarte y encontrar equilibrio sin importar el punto de partida. '
          'Cada sesión de masoterapia es una oportunidad de reconectar con tu cuerpo, '
          'liberar lo que ya no necesitas y renacer con más ligereza.',
          style: GoogleFonts.lato(fontSize: 15, color: _kTaupe, height: 1.75),
        ),
        const SizedBox(height: 20),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kLavender.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: _kLavender, width: 3)),
          ),
          child: Text(
            '"Bienestar que crece contigo — tu pausa perfecta."',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: _kLavender,
                height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(spacing: 32, runSpacing: 20, children: const [
          _AboutStat(value: '100%', label: 'Personalizado'),
          _AboutStat(value: '★ 5.0', label: 'Calificación'),
          _AboutStat(value: '∞', label: 'Dedicación'),
        ]),
      ],
    );
  }
}

class _KiriTreeIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5E6B52), _kOlive],
        ),
        boxShadow: [
          BoxShadow(
            color: _kOlive.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LeafPatternPainter())),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kLavender.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kTaupe.withValues(alpha: 0.20),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.park_rounded,
                          size: 38,
                          color: _kLavLight.withValues(alpha: 0.45)),
                      const SizedBox(width: 6),
                      Icon(Icons.park_rounded,
                          size: 80,
                          color: _kLavLight.withValues(alpha: 0.9)),
                      const SizedBox(width: 6),
                      Icon(Icons.park_rounded,
                          size: 38,
                          color: _kLavLight.withValues(alpha: 0.45)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                      height: 1.5,
                      width: 160,
                      color: Colors.white.withValues(alpha: 0.18)),
                  const SizedBox(height: 16),
                  Text(
                    'Paulownia · Árbol Kiri',
                    style: GoogleFonts.lato(
                        color: _kLavLight.withValues(alpha: 0.75),
                        fontSize: 11,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Crecimiento · Renovación · Arraigo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                        color: Colors.white,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: ['🌿 Bienestar', '🌱 Crecimiento', '✨ Renovación']
                        .map((lbl) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(lbl,
                                  style: GoogleFonts.lato(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KiriValuePillar extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  const _KiriValuePillar(
      {required this.emoji,
      required this.title,
      required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kTaupe.withValues(alpha: 0.14), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: _kOlive)),
          const SizedBox(height: 8),
          Text(description,
              softWrap: true,
              style: GoogleFonts.lato(
                  fontSize: 13, color: _kTaupe, height: 1.7)),
        ],
      ),
    );
  }
}

class _AboutStat extends StatelessWidget {
  final String value;
  final String label;
  const _AboutStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 30, fontWeight: FontWeight.bold, color: _kLavender)),
        Text(label,
            style: GoogleFonts.lato(
                fontSize: 13,
                color: _kTaupe,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact
// ─────────────────────────────────────────────────────────────────────────────

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCF9F4), Color(0xFFF7F0E7)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 88),
      child: Column(children: [
        Text('CONTÁCTANOS', style: GoogleFonts.lato(color: _kLavender,
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text('¿Lista para sentirte mejor?',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36, fontWeight: FontWeight.w700, color: _kOlive)),
        const SizedBox(height: 12),
        Text('Escríbenos o llámanos y con gusto agendamos tu cita.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
                fontSize: 16, color: _kTaupe, height: 1.5)),
        const SizedBox(height: 56),
        Wrap(
          spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
          children: [
            _ContactCard(
              icon: Icons.phone_rounded,
              title: 'Teléfono / WhatsApp',
              content: '8650-0843',
              onTap: () {
                html.window.location.href =
                    'https://wa.me/50686500843?text=Hola%2C%20quiero%20m%C3%A1s%20informaci%C3%B3n';
              },
            ),
            _ContactCard(
              icon: Icons.email_outlined,
              title: 'Correo electrónico',
              content: 'evelyn@kiriwellness.com',
              onTap: () {
                html.window.location.href = 'mailto:evelyn@kiriwellness.com';
              },
            ),
            _ContactCard(
              icon: Icons.person_outline_rounded,
              title: 'Masoterapeuta',
              content: 'Evelyn Hidalgo',
              onTap: null,
            ),
            _ContactCard(
              icon: Icons.camera_alt_outlined,
              title: 'Instagram',
              content: '@kiriwellness',
              onTap: () {
                html.window.location.href =
                    'https://www.instagram.com/kiriwellness';
              },
            ),
          ],
        ),
        const SizedBox(height: 56),
        ElevatedButton.icon(
          onPressed: () { html.window.location.href = '/#/book'; },
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: const Text('Reservar mi cita ahora'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kLavender,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
            textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final VoidCallback? onTap;
  const _ContactCard({required this.icon, required this.title,
      required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isDesktop ? 240 : 220,
        height: isDesktop ? 220 : null,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF7),
          borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kTaupe.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kLavender, size: 30),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center,
                style: GoogleFonts.lato(color: _kTaupe,
                    fontSize: 12, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(content, textAlign: TextAlign.center,
                style: GoogleFonts.lato(color: _kOlive,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            if (onTap != null) ...[
              const SizedBox(height: 10),
              Text('Toca para contactar',
                  style: GoogleFonts.lato(color: _kLavender, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF353D2E),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: '@kiriwellness en Instagram',
            child: IconButton(
              onPressed: () {
                html.window.location.href =
                    'https://www.instagram.com/kiriwellness';
              },
              icon: const Icon(Icons.camera_alt_outlined,
                  color: _kLavLight, size: 20),
            ),
          ),
          TextButton(
            onPressed: () { html.window.location.href = '/#/book'; },
            child: Text('Reservar cita',
                style: GoogleFonts.lato(color: _kLavLight, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  const _SectionHeading(
      {required this.tag, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tag, style: GoogleFonts.lato(color: _kLavender, fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 14),
        Text(title, style: GoogleFonts.cormorantGaramond(fontSize: isWide ? 42 : 36,
            fontWeight: FontWeight.w600, color: _kOlive, height: 1.2)),
        const SizedBox(height: 16),
        Text(subtitle, style: GoogleFonts.lato(
            fontSize: isWide ? 16 : 15, color: _kTaupe, height: 1.65)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kOlive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kOlive),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.lato(fontSize: 12,
            color: _kOlive, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaf pattern painter
// ─────────────────────────────────────────────────────────────────────────────

class _LeafPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final cx = size.width * (i % 3) / 2;
      final cy = size.height * (i ~/ 3) / 1.5 + size.height * 0.1;
      final path = Path()
        ..moveTo(cx, cy - 40)
        ..cubicTo(cx + 30, cy - 20, cx + 30, cy + 20, cx, cy + 40)
        ..cubicTo(cx - 30, cy + 20, cx - 30, cy - 20, cx, cy - 40);
      canvas.drawPath(path, paint);
    }
  }

  @override  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Package Dialog — public form for clients to request a package
// ─────────────────────────────────────────────────────────────────────────────

class _RequestPackageDialog extends StatefulWidget {
  final PackageModel pkg;
  const _RequestPackageDialog({required this.pkg});

  @override
  State<_RequestPackageDialog> createState() => _RequestPackageDialogState();
}

enum _ReqPhase { emailLookup, form, loading, success }

class _RequestPackageDialogState extends State<_RequestPackageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailLookupCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  _ReqPhase _phase = _ReqPhase.emailLookup;
  bool _lookingUp = false;
  bool _isReturningClient = false;
  String? _error;

  @override
  void dispose() {
    _emailLookupCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupEmail() async {
    final email = _emailLookupCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }
    setState(() { _lookingUp = true; _error = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('lookupClientByEmail');
      final result = await callable.call({'email': email});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['found'] == true) {
        _nameCtrl.text = data['firstName'] ?? '';
        _lastNameCtrl.text = data['lastName'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        setState(() { _isReturningClient = true; });
      } else {
        setState(() { _isReturningClient = false; });
      }
    } catch (_) {
      setState(() { _isReturningClient = false; });
    } finally {
      if (mounted) setState(() { _lookingUp = false; _phase = _ReqPhase.form; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _phase = _ReqPhase.loading; _error = null; });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('requestPackage');
      await callable.call({
        'packageId': widget.pkg.id,
        'firstName': _nameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': _emailLookupCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      });
      if (mounted) setState(() => _phase = _ReqPhase.success);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() { _phase = _ReqPhase.form; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _phase = _ReqPhase.form; _error = e.toString(); });
    }
  }

  InputDecoration _dec(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _kLavender, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kLavLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kLavLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kLavender, width: 2)),
        labelStyle: TextStyle(color: _kTaupe),
      );

  Widget _buildHeader() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kLavender.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.card_giftcard_outlined,
              color: _kLavender, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adquirir paquete',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _kOlive)),
                Text(widget.pkg.name,
                    style: GoogleFonts.lato(
                        fontSize: 13, color: _kTaupe)),
              ]),
        ),
        IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: _kTaupe, size: 20)),
      ]),
      const SizedBox(height: 4),
      Divider(color: _kLavLight.withValues(alpha: 0.5)),
      const SizedBox(height: 8),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: const Color(0xFFFAF8F4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _phase == _ReqPhase.success
              ? _SuccessView(pkg: widget.pkg, onClose: () => Navigator.of(context).pop())
              : _phase == _ReqPhase.emailLookup
                  ? _buildEmailLookupStep()
                  : _buildFormStep(),
        ),
      ),
    );
  }

  Widget _buildEmailLookupStep() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildHeader(),
      Text(
        'Ingresa tu correo electrónico para continuar',
        style: GoogleFonts.lato(fontSize: 14, color: _kTaupe, height: 1.5),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _emailLookupCtrl,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        onSubmitted: (_) => _lookupEmail(),
        decoration: _dec('Correo electrónico', 'tu@correo.com', Icons.email_outlined),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!,
            style: GoogleFonts.lato(color: Colors.red.shade700, fontSize: 13),
            textAlign: TextAlign.center),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _lookingUp ? null : _lookupEmail,
        style: FilledButton.styleFrom(
          backgroundColor: _kLavender,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _lookingUp
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('Continuar',
                style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    ],
  );

  Widget _buildFormStep() => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),

        // Returning client banner
        if (_isReturningClient) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kLavender.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kLavender.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.waving_hand_outlined, size: 16, color: _kLavender),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¡Bienvenida de vuelta! Encontramos tu información.',
                  style: GoogleFonts.lato(
                      fontSize: 12, color: _kLavender, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Info notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kOlive.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 15, color: _kOlive.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tu solicitud será revisada por nuestro equipo. Te notificaremos por correo una vez aprobada.',
                style: GoogleFonts.lato(fontSize: 12, color: _kOlive, height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Scrollable fields
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email (read-only, already captured)
                InputDecorator(
                  decoration: _dec('Correo electrónico', '', Icons.email_outlined),
                  child: Text(_emailLookupCtrl.text.trim(),
                      style: GoogleFonts.lato(fontSize: 14, color: _kOlive)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Nombre', 'Ej. María', Icons.person_outline),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Apellidos', 'Ej. González', Icons.person_outline),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Teléfono / WhatsApp', '+506 8888 8888', Icons.phone_outlined),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _dec('Notas adicionales (opcional)',
                      'Ej. método de pago, consultas...', Icons.note_outlined),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: GoogleFonts.lato(
                          color: Colors.red.shade700, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Row(children: [
          TextButton(
            onPressed: () => setState(() {
              _phase = _ReqPhase.emailLookup;
              _error = null;
            }),
            child: Text('← Cambiar correo',
                style: GoogleFonts.lato(color: _kTaupe, fontSize: 13)),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _phase == _ReqPhase.loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _kLavender,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _phase == _ReqPhase.loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Enviar solicitud',
                    style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
      ],
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final PackageModel pkg;
  final VoidCallback onClose;
  const _SuccessView({required this.pkg, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _kOlive.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.check_circle_outline, color: _kOlive, size: 40),
        ),
        const SizedBox(height: 20),
        Text('¡Solicitud enviada!',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, fontWeight: FontWeight.w700, color: _kOlive),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Tu solicitud para el paquete "${pkg.name}" fue recibida. Nuestro equipo la revisará y te notificará por correo electrónico una vez aprobada.',
          style: GoogleFonts.lato(fontSize: 14, color: _kTaupe, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(
            backgroundColor: _kLavender,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Cerrar',
              style:
                  GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
