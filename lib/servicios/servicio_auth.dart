import 'package:bcrypt/bcrypt.dart';
import 'package:payflow/datos/base_datos.dart';

class ServicioAuth {
  static bool contrasenaValida(String c) =>
      c.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(c) && RegExp(r'\d').hasMatch(c);

  /// Devuelve un mensaje de error, o null si la cuenta se creó.
  static Future<String?> crearCuenta(String usuario, String contrasena) async {
    final db = await BaseDatos.abrir();
    final existe = await db.query('usuario',
        where: 'nombre_usuario = ?', whereArgs: [usuario], limit: 1);
    if (existe.isNotEmpty) return 'Ese nombre de usuario ya está registrado.';
    final hash = BCrypt.hashpw(contrasena, BCrypt.gensalt());
    await db.insert('usuario', {'nombre_usuario': usuario, 'hash_contrasena': hash});
    return null;
  }

  /// Devuelve el id del usuario, o null si las credenciales no son válidas.
  static Future<int?> iniciarSesion(String usuario, String contrasena) async {
    final db = await BaseDatos.abrir();
    final f = await db.query('usuario',
        where: 'nombre_usuario = ? AND activo = 1', whereArgs: [usuario], limit: 1);
    if (f.isEmpty) return null;
    final ok = BCrypt.checkpw(contrasena, f.first['hash_contrasena'] as String);
    return ok ? f.first['id_usuario'] as int : null;
  }
}