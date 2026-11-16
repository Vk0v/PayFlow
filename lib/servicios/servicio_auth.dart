import 'package:bcrypt/bcrypt.dart';
import '../datos/base_datos.dart';

class ServicioAuth {
  /// Regla: mínimo 8 caracteres, una letra y un número.
  static bool contrasenaValida(String contrasena) =>
      contrasena.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(contrasena) &&
      RegExp(r'\d').hasMatch(contrasena);

  /// Devuelve null si todo salió bien, o el mensaje de error a mostrar.
  Future<String?> crearCuenta(String usuario, String contrasena) async {
    if (usuario.trim().isEmpty || contrasena.isEmpty) {
      return 'Completa los campos marcados con * para continuar.';
    }
    if (!contrasenaValida(contrasena)) {
      return 'La contraseña debe tener al menos 8 caracteres, con una letra y un número.';
    }

    final bd = await BaseDatos.instancia;
    final existe = await bd.query('usuario',
        where: 'nombre_usuario = ?', whereArgs: [usuario.trim()]);
    if (existe.isNotEmpty) {
      return 'Ese nombre de usuario ya existe. Elige otro.';
    }

    await bd.insert('usuario', {
      'nombre_usuario': usuario.trim(),
      'hash_contrasena': BCrypt.hashpw(contrasena, BCrypt.gensalt()),
    });
    return null;
  }

  /// Devuelve {id, nombre} si las credenciales son correctas, o null si no.
  Future<Map<String, dynamic>?> iniciarSesion(
      String usuario, String contrasena) async {
    final bd = await BaseDatos.instancia;
    final filas = await bd.query('usuario',
        where: 'nombre_usuario = ? AND activo = 1',
        whereArgs: [usuario.trim()]);
    if (filas.isEmpty) return null;

    final correcta =
        BCrypt.checkpw(contrasena, filas.first['hash_contrasena'] as String);
    if (!correcta) return null;

    return {
      'id': filas.first['id_usuario'] as int,
      'nombre': filas.first['nombre_usuario'] as String,
    };
  }
}