import 'package:flutter/material.dart';

class Colores {
  static const fondo = Color(0xFFF4F6FA);
  static const marino = Color(0xFF0F172A);
  static const verde = Color(0xFF0F7B4F);
  static const verdeClaro = Color(0xFFDCFCE7);
  static const ambar = Color(0xFFB45309);
  static const ambarClaro = Color(0xFFFEF3C7);
  static const rojo = Color(0xFFC62828);
  static const rojoClaro = Color(0xFFFDECEC);
  static const azul = Color(0xFF0369A1);
  static const azulClaro = Color(0xFFE0F2FE);
  static const texto = Color(0xFF0F172A);
  static const gris = Color(0xFF64748B);
  static const grisClaro = Color(0xFFE2E8F0);
  static const borde = Color(0xFFE2E8F0);
  static const blanco = Colors.white;
}

const estiloTitulo = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  color: Colores.texto,
);

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colores.marino)
        .copyWith(primary: Colores.marino),
    scaffoldBackgroundColor: Colores.fondo,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colores.blanco,
      foregroundColor: Colores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colores.blanco,
      indicatorColor: Colores.grisClaro,
      surfaceTintColor: Colors.transparent,
      height: 68,
    ),
  );
}