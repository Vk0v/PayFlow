import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/servicios/servicio_gasto.dart';
import 'package:payflow/servicios/servicio_periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';
import 'package:payflow/ui/pantallas/pantalla_compromisos_peligro.dart';
import 'package:payflow/ui/pantallas/pantalla_historial.dart';

class PantallaGastos extends StatefulWidget {
  const PantallaGastos({super.key});

  @override
  State<PantallaGastos> createState() => _EstadoGastos();
}

class _EstadoGastos extends State<PantallaGastos> {
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  int _categoria = 3;
  DateTime _fecha = DateTime.now();
  bool _ocupado = false;
  String? _error;
  Future<Periodo?>? _futuro;
  Future<List<String>>? _sugerencias;
  int _revisionVista = -1;

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha(Periodo p) async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.parse(p.fechaInicio),
      lastDate: DateTime.now(),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _registrar() async {
    final concepto = _concepto.text.trim();
    final monto = double.tryParse(_monto.text.trim()) ?? 0;
    if (concepto.isEmpty || monto <= 0) {
      setState(() => _error = 'Completa el concepto y un monto mayor a cero.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final id = context.read<EstadoApp>().idUsuario!;
    var r = await ServicioGasto.registrar(id,
        idCategoria: _categoria, concepto: concepto, monto: monto, fecha: _fecha);
    if (!mounted) return;

    if (r.estado == EstadoValidacion.riesgo) {
      setState(() => _ocupado = false);
      final seguir = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => PantallaCompromisosPeligro(
              resultado: r, concepto: concepto, monto: monto)));
      if (seguir != true || !mounted) return;
      setState(() => _ocupado = true);
      r = await ServicioGasto.registrar(id,
          idCategoria: _categoria,
          concepto: concepto,
          monto: monto,
          fecha: _fecha,
          aceptaRiesgo: true);
      if (!mounted) return;
    }
    setState(() => _ocupado = false);

    if (r.estado == EstadoValidacion.ok) {
      _concepto.clear();
      _monto.clear();
      context.read<EstadoApp>().notificarCambio();
      await mostrarAviso(context,
          titulo: 'Gasto registrado',
          mensaje:
              'Se registró **$concepto** por **${dinero(monto)}**. Saldo disponible: **${dinero(r.saldo)}**.');
    } else if (r.estado == EstadoValidacion.saldoInsuficiente) {
      await mostrarAviso(context,
          titulo: 'Saldo insuficiente',
          mensaje:
              'El gasto de **${dinero(monto)}** supera tu saldo disponible de **${dinero(r.saldo)}**.',
          icono: Icons.error_outline,
          color: Colores.rojo);
    } else if (r.estado == EstadoValidacion.bloqueado) {
      await mostrarAviso(context,
          titulo: 'Registro bloqueado',
          mensaje:
              'Tu periodo está en alerta de déficit. Corrige tus fondos en Ajustes de fondos.',
          icono: Icons.block,
          color: Colores.rojo);
    } else {
      await mostrarAviso(context,
          titulo: 'Fondos sin configurar',
          mensaje: 'Configura tu presupuesto en Ajustes de fondos para registrar gastos.',
          icono: Icons.info_outline,
          color: Colores.ambar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (_futuro == null || _revisionVista != app.revision) {
      _revisionVista = app.revision;
      _futuro = ServicioPeriodo.vigente(app.idUsuario!);
      _sugerencias = ServicioGasto.sugerencias(app.idUsuario!);
    }
    return FutureBuilder<Periodo?>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            CajaMensaje(nivel: NivelMensaje.error, texto: 'Error: ${snap.error}'),
          ]);
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = snap.data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (p == null)
              const CajaMensaje(
                nivel: NivelMensaje.aviso,
                titulo: 'Fondos sin configurar',
                texto: 'Configura tu presupuesto en Ajustes de fondos para registrar gastos.',
              )
            else if (p.enDeficit)
              const CajaMensaje(
                nivel: NivelMensaje.error,
                titulo: 'Registro de gastos bloqueado',
                texto: 'Tu periodo está en alerta de déficit. Corrige tus fondos en Ajustes de fondos.',
              )
            else ...[
              TarjetaPF(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Saldo disponible'),
                    Text(dinero(p.saldo),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              TarjetaPF(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Registrar gasto'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in [3, 4])
                          ChoiceChip(
                            label: Text(nombreCategoria(c)),
                            selected: _categoria == c,
                            selectedColor: Colores.marino,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                                color: _categoria == c ? Colors.white : Colores.texto,
                                fontWeight: FontWeight.w600),
                            onSelected: (_) => setState(() => _categoria = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CampoPF(
                        etiqueta: 'Concepto',
                        controlador: _concepto,
                        hint: 'Ej. Cine, luz, agua'),
                    FutureBuilder<List<String>>(
                      future: _sugerencias,
                      builder: (context, s) {
                        final l = s.data ?? const <String>[];
                        if (l.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              for (final x in l)
                                ActionChip(
                                  label: Text(x),
                                  onPressed: () =>
                                      setState(() => _concepto.text = x),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    CampoPF(
                      etiqueta: 'Monto',
                      controlador: _monto,
                      prefijo: '\$ ',
                      teclado: const TextInputType.numberWithOptions(decimal: true),
                      formatos: [soloMonto],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _elegirFecha(p),
                      icon: const Icon(Icons.event_outlined),
                      label: Text('Fecha: ${fechaLarga(fechaSql(_fecha))}'),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null)
                      CajaMensaje(nivel: NivelMensaje.error, texto: _error!),
                    BotonPF(
                        texto: 'Registrar gasto',
                        ocupado: _ocupado,
                        alPresionar: _registrar),
                  ],
                ),
              ),
            ],
            BotonPF(
              texto: 'Ver historial de movimientos',
              icono: Icons.history,
              tipo: TipoBoton.secundario,
              alPresionar: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaHistorial())),
            ),
          ],
        );
      },
    );
  }
}