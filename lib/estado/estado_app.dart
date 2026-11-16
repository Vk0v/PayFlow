import 'package:flutter/foundation.dart';

/// Estado global de la aplicación: quién inició sesión
/// y un contador que avisa cuando los datos cambian.
class EstadoApp extends ChangeNotifier {
  int? idUsuario;
  String nombreUsuario = '';
  int revision = 0;

  bool get haySesion => idUsuario != null;

  void iniciarSesion(int id, String nombre) {
    idUsuario = id;
    nombreUsuario = nombre;
    notifyListeners();
  }

  void cerrarSesion() {
    idUsuario = null;
    nombreUsuario = '';
    notifyListeners();
  }

  /// Avisa a las pantallas que deben volver a consultar los datos.
  void notificarCambio() {
    revision++;
    notifyListeners();
  }
}