import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/meta.dart';
import 'package:payflow/servicios/servicio_meta.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';

Future<bool> mostrarNuevaMeta(BuildContext context) async {
  final r = await showDialog<bool>(
      context: context, builder: (_) => const _DialogoNuevaMeta());
  return r == true;
}

Future<bool> mostrarAportar(
    BuildContext context, Meta meta, double disponible) async {
  final r = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAportar(meta: meta, disponible: disponible));
  return r == true;
}

Future<void> mostrarAportaciones(BuildContext context, Meta meta) async {
  final lista = await ServicioMeta.aportaciones(meta.id);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => VentanaPF(
      titulo: 'Aportaciones · ${meta.nombre}',
      icono: Icons.savings_outlined,
      contenido: Column(
        children: [
          if (lista.isEmpty)
            const Text('Aún no hay aportaciones.',
                style: TextStyle(color: Colores.gris)),
          for (final a in lista)
            FilaDato(fechaHoraLarga(a.fecha), dinero(a.monto)),
        ],
      ),
      acciones: [
        BotonPF(
            texto: 'Cerrar',
            tipo: TipoBoton.secundario,
            alPresionar: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

class _DialogoNuevaMeta extends StatefulWidget {
  const _DialogoNuevaMeta();

  @override
  State<_DialogoNuevaMeta> createState() => _EstadoNuevaMeta();
}

class _EstadoNuevaMeta extends State<_DialogoNuevaMeta> {
  final _nombre = TextEditingController();
  final _objetivo = TextEditingController();
  String? _limite;
  String? _error;
  bool _ocupado = false;

  @override
  void dispose() {
    _nombre.dispose();
    _objetivo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: hoy.add(const Duration(days: 30)),
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 10),
    );
    if (f != null) setState(() => _limite = fechaSql(f));
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final objetivo = double.tryParse(_objetivo.text.trim()) ?? 0;
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre de la meta.');
      return;
    }
    if (objetivo <= 0) {
      setState(() => _error = 'Ingresa un monto objetivo mayor a cero.');
      return;
    }
    setState(() => _ocupado = true);
    final id = context.read<EstadoApp>().idUsuario!;
    await ServicioMeta.crear(id, nombre, objetivo, _limite);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return VentanaPF(
      titulo: 'Nueva meta',
      icono: Icons.flag_outlined,
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampoPF(etiqueta: 'Nombre de la meta', controlador: _nombre),
          CampoPF(
            etiqueta: 'Monto objetivo',
            controlador: _objetivo,
            prefijo: '\$ ',
            teclado: const TextInputType.numberWithOptions(decimal: true),
            formatos: [soloMonto],
          ),
          OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(Icons.event_outlined),
            label: Text(_limite == null
                ? 'Fecha límite (opcional)'
                : fechaLarga(_limite!)),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            CajaMensaje(nivel: NivelMensaje.error, texto: _error!),
        ],
      ),
      acciones: [
        BotonPF(texto: 'Guardar meta', ocupado: _ocupado, alPresionar: _guardar),
        BotonPF(
            texto: 'Cancelar',
            tipo: TipoBoton.secundario,
            alPresionar: () => Navigator.pop(context, false)),
      ],
    );
  }
}

class _DialogoAportar extends StatefulWidget {
  final Meta meta;
  final double disponible;
  const _DialogoAportar({required this.meta, required this.disponible});

  @override
  State<_DialogoAportar> createState() => _EstadoAportar();
}

class _EstadoAportar extends State<_DialogoAportar> {
  final _monto = TextEditingController();
  String? _error;
  bool _ocupado = false;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _aportar() async {
    final monto = double.tryParse(_monto.text.trim()) ?? 0;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final id = context.read<EstadoApp>().idUsuario!;
    final error = await ServicioMeta.aportar(id, widget.meta.id, monto);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _ocupado = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return VentanaPF(
      titulo: 'Aportar a ${widget.meta.nombre}',
      icono: Icons.savings_outlined,
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilaDato('Ahorro disponible', dinero(widget.disponible)),
          FilaDato('Falta para la meta', dinero(widget.meta.faltante)),
          const SizedBox(height: 8),
          CampoPF(
            etiqueta: 'Monto a aportar',
            controlador: _monto,
            prefijo: '\$ ',
            teclado: const TextInputType.numberWithOptions(decimal: true),
            formatos: [soloMonto],
          ),
          if (_error != null)
            CajaMensaje(nivel: NivelMensaje.error, texto: _error!),
        ],
      ),
      acciones: [
        BotonPF(texto: 'Aportar', ocupado: _ocupado, alPresionar: _aportar),
        BotonPF(
            texto: 'Cancelar',
            tipo: TipoBoton.secundario,
            alPresionar: () => Navigator.pop(context, false)),
      ],
    );
  }
}