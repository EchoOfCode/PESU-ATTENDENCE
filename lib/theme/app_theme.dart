import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType { defaultTheme, funny, cute }

class AppTheme {
  final AppThemeType type;
  final String name;

  // Colors
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;
  final Color secondaryTextColor;
  
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;

  // Shapes
  final BorderRadius cardRadius;
  final Border? cardBorder;
  final List<BoxShadow>? cardShadow;

  // Typography
  final TextStyle Function({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    TextDecoration? decoration,
    double? letterSpacing,
  }) fontBuilder;

  // Status Strings
  final String msgSafe;
  final String msgWarning;
  final String msgDanger;
  
  // Bunk Planner Strings
  final String Function(int) msgCanSkip;
  final String Function(int) msgMustAttend;
  final String msgImpossible;
  final String msgExactlyTarget;

  const AppTheme({
    required this.type,
    required this.name,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
    required this.cardRadius,
    this.cardBorder,
    this.cardShadow,
    required this.fontBuilder,
    required this.msgSafe,
    required this.msgWarning,
    required this.msgDanger,
    required this.msgCanSkip,
    required this.msgMustAttend,
    required this.msgImpossible,
    required this.msgExactlyTarget,
  });

  static AppTheme get defaultTheme => AppTheme(
        type: AppThemeType.defaultTheme,
        name: 'Default',
        backgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
        textColor: Colors.white,
        secondaryTextColor: const Color(0xFF8B949E),
        safeColor: const Color(0xFF22C55E),
        warningColor: const Color(0xFFFACC15),
        dangerColor: const Color(0xFFEF4444),
        cardRadius: BorderRadius.circular(14),
        cardBorder: Border.all(color: Colors.white.withAlpha(12)),
        cardShadow: null,
        fontBuilder: GoogleFonts.inter,
        msgSafe: "Great! You're well above the threshold.",
        msgWarning: "Getting close to threshold.",
        msgDanger: "Danger! Below attendance threshold.",
        msgCanSkip: (x) => "Can bunk $x class${x == 1 ? '' : 'es'}",
        msgMustAttend: (x) => "Must attend $x class${x == 1 ? '' : 'es'}",
        msgImpossible: "Impossible to reach target.",
        msgExactlyTarget: "Exactly at target — don't skip!",
      );

  static AppTheme get funnyTheme => AppTheme(
        type: AppThemeType.funny,
        name: 'Procrastinator',
        backgroundColor: const Color(0xFFFFD54F),
        cardColor: Colors.white,
        textColor: Colors.black,
        secondaryTextColor: Colors.black87,
        safeColor: const Color(0xFF10B981), // darker green for contrast
        warningColor: const Color(0xFFF59E0B), // darker orange
        dangerColor: const Color(0xFFDC2626), // darker red
        cardRadius: BorderRadius.zero,
        cardBorder: Border.all(color: Colors.black, width: 3),
        cardShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
        ],
        fontBuilder: GoogleFonts.comicNeue,
        msgSafe: "Nerd alert. Go touch grass.",
        msgWarning: "Living on the edge. Try not to oversleep.",
        msgDanger: "gg wp. Hope you like summer school.",
        msgCanSkip: (x) => "You can legally sleep through $x classes",
        msgMustAttend: (x) => "Wake up bro, attend $x more",
        msgImpossible: "Bro you're cooked. It's impossible.",
        msgExactlyTarget: "Don't even breathe.",
      );

  static AppTheme get cuteTheme => AppTheme(
        type: AppThemeType.cute,
        name: 'UwU Kawaii',
        backgroundColor: const Color(0xFFFFF0F5),
        cardColor: Colors.white,
        textColor: const Color(0xFF5D3A9B),
        secondaryTextColor: const Color(0xFF9B7EBD),
        safeColor: const Color(0xFF5ED5A8), // Mint green
        warningColor: const Color(0xFFFFB26B), // Soft orange
        dangerColor: const Color(0xFFFF9AA2), // Soft pink-red
        cardRadius: BorderRadius.circular(30),
        cardBorder: Border.all(color: const Color(0x225D3A9B), width: 1.5),
        cardShadow: const [
          BoxShadow(color: Color(0x19FFB6C1), blurRadius: 20, spreadRadius: 2, offset: Offset(0, 8)),
        ],
        fontBuilder: GoogleFonts.quicksand,
        msgSafe: "You're doing amazing, sweetie! 🌸",
        msgWarning: "Be careful, pookie! 🥺",
        msgDanger: "Oh no! Please go to class! 😭",
        msgCanSkip: (x) => "You earned $x nap times ✨",
        msgMustAttend: (x) => "Senpai notices you, attend $x more 🥺",
        msgImpossible: "It's mathematically over 😭",
        msgExactlyTarget: "Right on the edge 🥺",
      );
}
