import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflow/utilidades/tema.dart';

Color colorEstado(int id) =>
    id == 2 ? Colores.verde : (id == 3 ? Colores.ambar : Colores.rojo);

Color fondoEstado(int id) => id == 2
    ? Colores.verdeClaro
    : (id == 3 ? Colores.ambarClaro : Colores.rojoClaro);

final soloMonto = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

/// Texto con **negritas**.
Widget textoConNegritas(String texto, TextStyle estilo,
    {TextAlign alineacion = TextAlign.start}) {
  final partes = texto.split('**');
  return Text.rich(
    TextSpan(
      style: estilo,
      children: [
        for (var i = 0; i < partes.length; i++)
          TextSpan(
            text: partes[i],
            style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
      ],
    ),
    textAlign: alineacion,
  );
}

class EtiquetaSeccion extends StatelessWidget {
  final String texto;
  const EtiquetaSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colores.gris,
        ),
      ),
    );
  }
}

class TarjetaPF extends StatelessWidget {
  final Widget hijo;
  final Color? borde;
  final Color? fondo;
  final EdgeInsets relleno;
  final double separacion;
  final VoidCallback? alTocar;

  const TarjetaPF({
    super.key,
    required this.hijo,
    this.borde,
    this.fondo,
    this.relleno = const EdgeInsets.all(16),
    this.separacion = 12,
    this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: separacion),
      child: Material(
        color: fondo ?? Colores.blanco,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borde ?? Colores.borde),
        ),
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: relleno,
            child: SizedBox(width: double.infinity, child: hijo),
          ),
        ),
      ),
    );
  }
}

enum TipoBoton { primario, verde, peligro, secundario }

/// Ocupa todo el ancho disponible (dentro de un Row, envuélvelo en Expanded).
class BotonPF extends StatelessWidget {
  final String texto;
  final VoidCallback? alPresionar;
  final TipoBoton tipo;
  final bool ocupado;
  final IconData? icono;
  final bool compacto;

  const BotonPF({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.tipo = TipoBoton.primario,
    this.ocupado = false,
    this.icono,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final deshabilitado = alPresionar == null || ocupado;
    final secundario = tipo == TipoBoton.secundario;
    final colorTexto = secundario ? Colores.marino : Colors.white;
    final hijo = ocupado
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: colorTexto),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[Icon(icono, size: 18), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
    final relleno = EdgeInsets.symmetric(
        vertical: compacto ? 10 : 15, horizontal: compacto ? 12 : 20);
    final forma = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compacto ? 10 : 14));
    final VoidCallback? accion = deshabilitado ? null : alPresionar;

    Widget boton;
    if (secundario) {
      boton = OutlinedButton(
        onPressed: accion,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colores.marino,
          side: const BorderSide(color: Colores.borde),
          padding: relleno,
          shape: forma,
        ),
        child: hijo,
      );
    } else {
      final color = tipo == TipoBoton.verde
          ? Colores.verde
          : (tipo == TipoBoton.peligro ? Colores.rojo : Colores.marino);
      boton = FilledButton(
        onPressed: accion,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: relleno,
          shape: forma,
        ),
        child: hijo,
      );
    }
    return SizedBox(width: double.infinity, child: boton);
  }
}

class CampoPF extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controlador;
  final String? hint;
  final TextInputType? teclado;
  final bool oculto;
  final String? prefijo;
  final ValueChanged<String>? alCambiar;
  final int? maxLongitud;
  final List<TextInputFormatter>? formatos;
  final bool habilitado;
  final String? error;

  const CampoPF({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.hint,
    this.teclado,
    this.oculto = false,
    this.prefijo,
    this.alCambiar,
    this.maxLongitud,
    this.formatos,
    this.habilitado = true,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color c, [double ancho = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: ancho),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colores.gris,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controlador,
            keyboardType: teclado,
            obscureText: oculto,
            onChanged: alCambiar,
            maxLength: maxLongitud,
            inputFormatters: formatos,
            enabled: habilitado,
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefijo,
              errorText: error,
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: borde(Colores.borde),
              enabledBorder: borde(Colores.borde),
              focusedBorder: borde(Colores.marino, 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

enum NivelMensaje { info, exito, aviso, error }

class CajaMensaje extends StatelessWidget {
  final NivelMensaje nivel;
  final String texto;
  final String? titulo;

  const CajaMensaje({
    super.key,
    required this.nivel,
    required this.texto,
    this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color fondo;
    IconData icono;
    switch (nivel) {
      case NivelMensaje.exito:
        color = Colores.verde;
        fondo = Colores.verdeClaro;
        icono = Icons.check_circle_outline;
        break;
      case NivelMensaje.aviso:
        color = Colores.ambar;
        fondo = Colores.ambarClaro;
        icono = Icons.warning_amber_rounded;
        break;
      case NivelMensaje.error:
        color = Colores.rojo;
        fondo = Colores.rojoClaro;
        icono = Icons.error_outline;
        break;
      case NivelMensaje.info:
        color = Colores.azul;
        fondo = Colores.azulClaro;
        icono = Icons.info_outline;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(titulo!,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: color)),
                  ),
                textoConNegritas(
                    texto, const TextStyle(fontSize: 13, color: Colores.texto)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CajaCamposPendientes extends StatelessWidget {
  final List<String> campos;
  const CajaCamposPendientes(this.campos, {super.key});

  @override
  Widget build(BuildContext context) {
    if (campos.isEmpty) return const SizedBox.shrink();
    return CajaMensaje(
      nivel: NivelMensaje.aviso,
      titulo: 'Campos pendientes',
      texto: 'Completa: ${campos.join(', ')}.',
    );
  }
}

class EtiquetaEstado extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  const EtiquetaEstado(this.texto, this.color, this.fondo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class BarraProgreso extends StatelessWidget {
  final double valor;
  final Color color;
  const BarraProgreso({super.key, required this.valor, this.color = Colores.verde});

  @override
  Widget build(BuildContext context) {
    final v = valor.isNaN ? 0.0 : valor.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 8,
        backgroundColor: Colores.grisClaro,
        color: color,
      ),
    );
  }
}

class IconoCuadro extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color fondo;
  final double tam;
  const IconoCuadro(
    this.icono, {
    super.key,
    this.color = Colores.marino,
    this.fondo = Colores.grisClaro,
    this.tam = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tam,
      height: tam,
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Icon(icono, color: color, size: tam * 0.52),
    );
  }
}

class LogoPF extends StatelessWidget {
  final double tam;
  const LogoPF({super.key, this.tam = 40});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tam * 0.25),
      child: Image.asset(
        'assets/logo.png',
        width: tam,
        height: tam,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: tam,
          height: tam,
          color: Colores.marino,
          alignment: Alignment.center,
          child: Text('P',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: tam * 0.5)),
        ),
      ),
    );
  }
}

class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? colorValor;
  const FilaDato(this.etiqueta, this.valor, {super.key, this.colorValor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(etiqueta,
                style: const TextStyle(color: Colores.gris, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: colorValor ?? Colores.texto),
            ),
          ),
        ],
      ),
    );
  }
}