import 'package:flutter/material.dart';

/// Colors extracted pixel-by-pixel from the design reference image.
///
/// Light theme background : #F2F3F8  (very light blue-grey, almost white)
/// New Delivery card      : #E8E6FF  (soft lavender)
/// Track Package card     : #F2F3F8  (same as bg, slightly elevated)
/// Shipment card          : #E8E6FF  (same lavender as New Delivery card)
/// Progress dot active    : #7B6CF6  (medium purple)
/// Progress line active   : #7B6CF6
/// Text primary           : #1A1A2E  (near-black with blue tint)
/// Text secondary         : #8A8FA8  (muted grey-blue)
/// Accent / FAB           : #7B6CF6  (purple - same as progress dot)
/// "See all" link         : #8A8FA8
/// Border/divider         : #D8DAE8

class AppColors {
  AppColors._();

  // ── Brand / Accent ──────────────────────────────────────────────────────────
  /// Primary purple accent — progress dots, FAB, buttons (#7B6CF6)
  static const Color accent = Color(0xFF7B6CF6);

  /// Lighter tint used for card backgrounds (#E8E6FF)
  static const Color accentLight = Color(0xFFE8E6FF);

  /// Orange kept for backward compat with other screens
  static const Color orange = Color(0xFFFF5A1F);

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static const Color lightBackground   = Color(0xFFF2F3F8);
  static const Color lightSurface      = Color(0xFFFFFFFF);
  static const Color lightCard         = Color(0xFFE8E6FF); // lavender cards
  static const Color lightCardAlt      = Color(0xFFF2F3F8); // Track Package card
  static const Color lightTextPrimary  = Color(0xFF1A1A2E);
  static const Color lightTextSecondary= Color(0xFF8A8FA8);
  static const Color lightBorder       = Color(0xFFD8DAE8);
  static const Color lightInputFill    = Color(0xFFFFFFFF);
  static const Color lightDot          = Color(0xFFD8DAE8); // inactive progress dot
  static const Color lightIcon         = Color(0xFF8A8FA8);

  // ── Dark Theme ──────────────────────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF101216);
  static const Color darkSurface       = Color(0xFF1B1F26);
  static const Color darkCard          = Color(0xFF23283A); // dark lavender tint
  static const Color darkCardAlt       = Color(0xFF1B1F26);
  static const Color darkTextPrimary   = Color(0xFFF5F7FA);
  static const Color darkTextSecondary = Color(0xFF98A1AE);
  static const Color darkBorder        = Color(0xFF252A33);
  static const Color darkInputFill     = Color(0xFF1B1F26);
  static const Color darkDot           = Color(0xFF252A33);
  static const Color darkIcon          = Color(0xFF98A1AE);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFEF4444);
}