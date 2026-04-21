import 'package:flutter/material.dart';

/// Clase que contiene todos los colores de la aplicación
/// Patrón de arquitectura: Constantes centralizadas
class AppColors {
  // Colores primarios (Purple)
  static const Color primary = Color(0xFFa855f7); // purple-500
  static const Color primaryLight = Color(0xFFc084fc); // purple-400
  static const Color primaryDark = Color(0xFF7c3aed); // purple-700
  static const Color primaryDeep = Color(0xFF581c87); // purple-900
  static const Color accentGlow = Color(0xFF7c3aed); // glow color

  // Colores secundarios
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  // Colores neutros (Super Dark Theme)
  static const Color background = Color(0xFF0a0a0a); // surface-950
  static const Color surface = Color(0xFF0f0f14); // surface-900
  static const Color surfaceVariant = Color(0xFF16161d); // surface-800
  static const Color surfaceLight = Color(0xFF1e1e28); // surface-700
  static const Color surfaceLighter = Color(0xFF2a2a38); // surface-600

  // Colores de texto
  static const Color textPrimary = Color(0xFFe2e8f0);
  static const Color textSecondary = Color(0xFF9ca3af);
  static const Color textTertiary = Color(0xFF6b7280);
  static const Color textHint = Color(0xFF4b5563);

  // Colores de estado
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);

  // Colores de borde
  static const Color border = Color(0xFF2a2a38); // surface-600
  static const Color borderDark = Color(0xFF16161d); // surface-800

  // Colores transparentes (Glass)
  static const Color overlay = Color(0x99000000); // Darker scrim
  static const Color glassBorder = Color(0x267c3aed); // Purple 15% opacity
  static const Color glassBackground = Color(0x991e1e28); // Surface 60% opacity

  // Constructor privado para evitar instanciación
  AppColors._();
}
