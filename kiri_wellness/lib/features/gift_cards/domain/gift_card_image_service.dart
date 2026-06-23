import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/gift_card_repository.dart';
import '../../../shared/models/gift_card_model.dart';

// ---------------------------------------------------------------------------
// GiftCardImageService
//
// Generates a print-ready PNG (1004 × 638 px ≈ 8.5 × 5.4 cm at 300 dpi)
// for a Kiri Wellness gift card and uploads it to Firebase Storage.
// ---------------------------------------------------------------------------

class GiftCardImageService {
  final GiftCardRepository _repo;

  GiftCardImageService(this._repo);

  // Card dimensions at 300 dpi: 8.5 cm × 5.4 cm
  static const double _cardW = 1004;
  static const double _cardH = 638;

  // Brand colours (matching AppTheme)
  static const ui.Color _lavender = ui.Color(0xFF9D87BC);
  static const ui.Color _lavenderLight = ui.Color(0xFFD4C8E8);
  static const ui.Color _olive = ui.Color(0xFF4A5240);
  static const ui.Color _white = ui.Color(0xFFFFFFFF);

  // ── Code generator ────────────────────────────────────────────────────────

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final part = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'KIRI-$part';
  }

  // ── Single card creation ──────────────────────────────────────────────────

  /// Creates a [GiftCardModel] document, renders the image and stores it.
  Future<GiftCardModel> createCard() async {
    final code = _generateCode();
    final now = DateTime.now();

    // 1. Save document first to get the Firestore ID
    final cardId = await _repo.create(GiftCardModel(
      id: '',
      code: code,
      status: GiftCardStatus.available,
      createdAt: now,
    ));

    // 2. Render PNG
    final pngBytes = await _renderCard(code);

    // 3. Upload to Storage
    final url = await _repo.uploadImage(cardId, pngBytes);

    // 4. Persist URL
    await _repo.saveImageUrl(cardId, url);

    return GiftCardModel(
      id: cardId,
      code: code,
      status: GiftCardStatus.available,
      imageUrl: url,
      createdAt: now,
    );
  }

  /// Generates [count] cards in batch.
  Future<List<GiftCardModel>> createBatch(int count) async {
    final results = <GiftCardModel>[];
    for (var i = 0; i < count; i++) {
      results.add(await createCard());
    }
    return results;
  }

  // ── Canvas renderer ───────────────────────────────────────────────────────

  Future<Uint8List> _renderCard(String code) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, _cardW, _cardH),
    );

    // ── Background gradient ──────────────────────────────────────────────────
    final bgPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(_cardW, _cardH),
        [_olive, const ui.Color(0xFF2D2A25)],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, _cardW, _cardH),
        const ui.Radius.circular(36),
      ),
      bgPaint,
    );

    // ── Decorative circles ───────────────────────────────────────────────────
    final circlePaint = ui.Paint()
      ..color = _lavender.withValues(alpha: 0.12)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(_cardW * 0.85, _cardH * 0.15), 180, circlePaint);
    canvas.drawCircle(ui.Offset(_cardW * 0.1, _cardH * 0.9), 140, circlePaint);

    final circleBorder = ui.Paint()
      ..color = _lavenderLight.withValues(alpha: 0.18)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(ui.Offset(_cardW * 0.85, _cardH * 0.15), 250, circleBorder);

    // ── Left accent stripe ───────────────────────────────────────────────────
    final stripePaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(0, _cardH),
        [_lavender, _lavenderLight.withValues(alpha: 0.4)],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 0, 8, _cardH),
        const ui.Radius.circular(4),
      ),
      stripePaint,
    );

    // ── Logo (from assets) ───────────────────────────────────────────────────
    try {
      final data = await rootBundle.load('assets/images/kiriwellness.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 280,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final logoRect = ui.Rect.fromLTWH(
        40,
        40,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        logoRect,
        ui.Paint(),
      );
    } catch (_) {
      // Fallback text if image cannot be loaded
      _drawText(canvas, 'KIRI WELLNESS', 44, _lavenderLight,
          ui.Offset(40, 44), bold: true);
    }

    // ── "Tarjeta de Regalo" label ────────────────────────────────────────────
    _drawText(canvas, 'TARJETA DE REGALO', 28, _lavenderLight,
        ui.Offset(40, _cardH * 0.52));

    // ── Code ─────────────────────────────────────────────────────────────────
    // Code pill background
    final pillRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(40, _cardH * 0.63, 460, 80),
      const ui.Radius.circular(16),
    );
    canvas.drawRRect(
      pillRect,
      ui.Paint()..color = _lavender.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      pillRect,
      ui.Paint()
        ..color = _lavenderLight.withValues(alpha: 0.4)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawText(canvas, code, 42, _white,
        ui.Offset(50, _cardH * 0.63 + 20),
        bold: true, letterSpacing: 4);

    // ── Bottom tagline ────────────────────────────────────────────────────────
    _drawText(
      canvas,
      'Presenta este código al momento de agendar tu cita',
      18,
      _lavenderLight.withValues(alpha: 0.7),
      ui.Offset(40, _cardH - 52),
    );

    // ── Render ────────────────────────────────────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(_cardW.toInt(), _cardH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawText(
    ui.Canvas canvas,
    String text,
    double fontSize,
    ui.Color color,
    ui.Offset offset, {
    bool bold = false,
    double letterSpacing = 0,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontFamily: 'Lato',
      fontSize: fontSize,
      fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        letterSpacing: letterSpacing,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      ))
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: _cardW - offset.dx - 40));
    canvas.drawParagraph(paragraph, offset);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final giftCardImageServiceProvider = Provider<GiftCardImageService>(
  (ref) => GiftCardImageService(ref.watch(giftCardRepositoryProvider)),
);
