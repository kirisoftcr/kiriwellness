// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/service_model.dart';
import '../../../shared/models/package_model.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
// Extracted from the official Kiri Wellness brand guide
const _kOlive      = Color(0xFF4A5240); // dark olive green
const _kTaupe      = Color(0xFF9B8B7A); // warm taupe
const _kLavender   = Color(0xFF9D87BC); // soft lavender/purple
const _kLavLight   = Color(0xFFD4C8E8); // lavender light
const _kCream      = Color(0xFFF0EBE0); // warm cream background
const _kCreamDark  = Color(0xFFE6DFCF); // slightly darker cream
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroSection(onBook: () => context.go('/book')),
            const _BenefitsStrip(),
            const _ServicesSection(),
            const _PackagesSection(),
            const _AboutSection(),
            const _ContactSection(),
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
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOlive, Color(0xFF5E6B52), Color(0xFF7A8A6E)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LeafPatternPainter())),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 24,
              vertical: isWide ? 80 : 56,
            ),
            child: isWide
                ? Row(children: [
                    Expanded(flex: 3, child: _HeroText(onBook: onBook)),
                    const SizedBox(width: 60),
                    Expanded(flex: 2, child: _HeroIllustration()),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _HeroText(onBook: onBook, centered: true),
                    const SizedBox(height: 40),
                    _HeroIllustration(),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final VoidCallback onBook;
  final bool centered;
  const _HeroText({required this.onBook, this.centered = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Brand logo — constrain by width for landscape PNG
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Image.asset(
            'assets/images/kiriwellness.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Tu momento de\nbienestar comienza aquí',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.cormorantGaramond(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Masoterapia profesional para aliviar tensiones,\nrestaurar tu energía y cuidar tu cuerpo.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.lato(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.calendar_today_rounded, size: 17),
              label: const Text('Reservar una cita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                html.window.location.href =
                    'https://wa.me/50686500843?text=Hola%2C%20quiero%20m%C3%A1s%20informaci%C3%B3n';
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 17),
              label: const Text('WhatsApp'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 24, right: 24,
            child: Container(width: 70, height: 70,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _kLavender.withValues(alpha: 0.2))),
          ),
          Positioned(
            bottom: 32, left: 24,
            child: Container(width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _kTaupe.withValues(alpha: 0.25))),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.spa_rounded, size: 72,
                color: _kLavLight.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text('Tu espacio de relajación',
                style: GoogleFonts.cormorantGaramond(
                    color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Container(margin: const EdgeInsets.symmetric(horizontal: 40),
                height: 1, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('✦  Masoterapia  ·  Bienestar  ✦',
                style: GoogleFonts.lato(color: _kLavLight.withValues(alpha: 0.7),
                    fontSize: 11, letterSpacing: 2)),
          ]),
        ],
      ),
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
      color: _kCream,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            tag: 'NUESTROS SERVICIOS',
            title: 'Terapias diseñadas\npara ti',
            subtitle: 'Cada sesión es personalizada para atender tus necesidades físicas y emocionales.',
          ),
          const SizedBox(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
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
        return SizedBox(width: width.clamp(240, 400), child: _ServiceCard(service: s));
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCreamDark),
        boxShadow: [BoxShadow(color: _kOlive.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 13, color: _kTaupe, height: 1.55)),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(icon: Icons.schedule_outlined, label: '${service.durationMinutes} min'),
            if (service.price > 0)
              _Chip(icon: Icons.attach_money_rounded,
                  label: '₡${service.price.toStringAsFixed(0)}'),
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
      color: _kOlive.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            tag: 'PAQUETES',
            title: 'Ahorra más con\nnuestros paquetes',
            subtitle: 'Combina sesiones de diferentes terapias y obtén un precio especial.',
          ),
          const SizedBox(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLavLight.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: _kLavender.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
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
                style: GoogleFonts.lato(fontSize: 13, color: _kTaupe, height: 1.55)),
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
              Text('₡${pkg.price.toStringAsFixed(0)}',
                  style: GoogleFonts.cormorantGaramond(fontSize: 24,
                      fontWeight: FontWeight.bold, color: _kOlive)),
            ]),
            const Spacer(),
            if (pkg.validityDays > 0)
              _Chip(icon: Icons.calendar_today_outlined, label: '${pkg.validityDays} días'),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About
// ─────────────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Container(
      color: _kCream,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 64),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: _AboutIllustration()),
              const SizedBox(width: 60),
              Expanded(child: _AboutText()),
            ])
          : Column(children: [_AboutIllustration(), const SizedBox(height: 40), _AboutText()]),
    );
  }
}

class _AboutIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOlive, Color(0xFF6B7A5E)],
        ),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _LeafPatternPainter())),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.self_improvement_rounded, size: 72,
              color: _kLavLight.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text('"Tu pausa perfecta\nte espera"',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                  color: Colors.white, fontSize: 20,
                  fontStyle: FontStyle.italic, height: 1.4)),
        ])),
      ]),
    );
  }
}

class _AboutText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SOBRE KIRI WELLNESS',
            style: GoogleFonts.lato(color: _kLavender, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text('Masoterapia profesional\ncon corazón',
            style: GoogleFonts.cormorantGaramond(fontSize: 34,
                fontWeight: FontWeight.w600, color: _kOlive, height: 1.2)),
        const SizedBox(height: 20),
        Text(
          'En Kiri Wellness creemos que el bienestar es una necesidad, no un lujo. '
          'Ofrecemos sesiones de masoterapia terapéutica y de relajación, adaptadas '
          'a cada persona, para que puedas liberar tensiones, recuperar energía y '
          'sentirte en equilibrio.',
          style: GoogleFonts.lato(fontSize: 15, color: _kTaupe, height: 1.7),
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

class _AboutStat extends StatelessWidget {
  final String value;
  final String label;
  const _AboutStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.cormorantGaramond(
            fontSize: 30, fontWeight: FontWeight.bold, color: _kLavender)),
        Text(label, style: GoogleFonts.lato(
            fontSize: 13, color: _kTaupe, fontWeight: FontWeight.w500)),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOlive, Color(0xFF5E6B52)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 64),
      child: Column(children: [
        Text('CONTÁCTANOS', style: GoogleFonts.lato(color: _kLavLight,
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text('¿Lista para sentirte mejor?',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 12),
        Text('Escríbenos o llámanos y con gusto agendamos tu cita.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
                fontSize: 16, color: Colors.white.withValues(alpha: 0.8), height: 1.5)),
        const SizedBox(height: 48),
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
              title: 'Terapeuta',
              content: 'Evelyn Hidalgo',
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 48),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: _kLavLight, size: 32),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(content, textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w600)),
          if (onTap != null) ...[
            const SizedBox(height: 10),
            Text('Toca para contactar',
                style: GoogleFonts.lato(color: _kLavLight, fontSize: 11)),
          ],
        ]),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/kiriwellness.png',
            height: 52,
            fit: BoxFit.contain,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tag, style: GoogleFonts.lato(color: _kLavender, fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 10),
        Text(title, style: GoogleFonts.cormorantGaramond(fontSize: 36,
            fontWeight: FontWeight.w600, color: _kOlive, height: 1.2)),
        const SizedBox(height: 12),
        Text(subtitle, style: GoogleFonts.lato(
            fontSize: 15, color: _kTaupe, height: 1.65)),
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