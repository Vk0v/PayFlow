import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/corte.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/servicios/servicio_corte.dart';
import 'package:payflow/servicios/servicio_periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';
import 'package:payflow/ui/pantallas/pantalla_corte.dart';

class VistaConfigPeriodo extends StatefulWidget {
  const VistaConfigPeriodo({super.key});

  @override
  State<VistaConfigPeriodo> createState() => _EstadoConfig();
}

class _EstadoConfig extends State<VistaConfigPeriodo> {
  final _pmt = TextEditingController();
  final _ahorro = TextEditingController();
  Future<Periodo?>? _futuro;
  Future<CorteCaja?>? _futuroCorte;
  int _revisionVista = -1;
  bool _precargado = false;
  bool _mostrarDeficit = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _pmt.dispose();
    _ahorro.dispose();
    super.dispose();
  }

  Future<void> _guardar(double pmt, double ahorro) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Confirmar configuración?',
      mensaje:
          'PMT **${dinero(pmt)}** y ahorro objetivo **${dinero(ahorro)}**. Una vez configurados no podrás modificarlos hasta el siguiente periodo.',
      textoSi: 'Confirmar',
    );
    if (!ok || !mounted) return;
    setState(() => _ocupado = true);
    final id = context.read<EstadoApp>().idUsuario!;
    final r = await ServicioPeriodo.configurar(id, pmt, ahorro);
    if (!mounted) return;
    setState(() => _ocupado = false);
    context.read<EstadoApp>().notificarCambio();
    if (r == ResultadoConfig.ok) {
      await mostrarAviso(context,
          titulo: 'Configuración guardada',
          mensaje: 'Tus fondos del periodo quedaron configurados.');
    } else if (r == ResultadoConfig.deficit) {
      setState(() => _mostrarDeficit = true);
    } else {
      await mostrarAviso(context,
          titulo: 'Periodo ya configurado',
          mensaje: 'Los fondos de este periodo ya fueron definidos.',
          icono: Icons.info_outline,
          color: Colores.azul);
    }
  }

  Future<void> _forzarCorte() async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Forzar corte de caja?',
      mensaje: 'Se cerrará el periodo actual ahora mismo (modo demostración).',
      textoSi: 'Ejecutar corte',
      peligro: true,
    );
    if (!ok || !mounted) return;
    final app = context.read<EstadoApp>();
    final corte =
        await ServicioCorte.ejecutarSiCorresponde(app.idUsuario!, forzar: true);
    if (!mounted) return;
    app.notificarCambio();
    if (corte == null) {
      await mostrarAviso(context,
          titulo: 'Sin periodo abierto',
          mensaje: 'No hay un periodo configurado para cerrar.',
          icono: Icons.info_outline,
          color: Colores.azul);
    } else {
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaCorte(corte: corte)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (_futuro == null || _revisionVista != app.revision) {
      _revisionVista = app.revision;
      _futuro = ServicioPeriodo.vigente(app.idUsuario!);
      _futuroCorte = ServicioCorte.ultimo(app.idUsuario!);
      _precargado = false;
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
        return _contenido(snap.data);
      },
    );
  }

  Widget _contenido(Periodo? p) {
    final editable = p == null || p.enDeficit;
    if (editable && !_precargado) {
      if (p != null) {
        _pmt.text = p.pmt > 0 ? p.pmt.toStringAsFixed(2) : '';
        _ahorro.text = p.ahorroObjetivo.toStringAsFixed(2);
      }
      _precargado = true;
    }
    final pmt = double.tryParse(_pmt.text.trim()) ?? 0;
    final ahorro = double.tryParse(_ahorro.text.trim()) ?? 0;
    final libre = pmt - ahorro;

    if (editable && _mostrarDeficit) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        CajaMensaje(
          nivel: NivelMensaje.error,
          titulo: 'Alerta de déficit presupuestario',
          texto:
              'Con un PMT de **${dinero(pmt)}** y un ahorro objetivo de **${dinero(ahorro)}** no queda saldo para gastos. Ajusta los montos para continuar.',
        ),
        BotonPF(
            texto: 'Regresar',
            alPresionar: () => setState(() => _mostrarDeficit = false)),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (editable) ...[
          TarjetaPF(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EtiquetaSeccion('Fondos del periodo'),
                CampoPF(
                  etiqueta: 'Presupuesto mensual total (PMT)',
                  controlador: _pmt,
                  prefijo: '\$ ',
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  formatos: [soloMonto],
                  alCambiar: (_) => setState(() {}),
                ),
                CampoPF(
                  etiqueta: 'Ahorro objetivo',
                  controlador: _ahorro,
                  prefijo: '\$ ',
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  formatos: [soloMonto],
                  alCambiar: (_) => setState(() {}),
                ),
                FilaDato('Disponible para gastos', dinero(libre > 0 ? libre : 0)),
              ],
            ),
          ),
          if (pmt > 0 && ahorro >= pmt)
            const CajaMensaje(
              nivel: NivelMensaje.error,
              titulo: 'Déficit presupuestario',
              texto:
                  'El ahorro objetivo es igual o mayor al PMT: no habría dinero para gastos.',
            ),
          BotonPF(
            texto: 'Guardar configuración',
            ocupado: _ocupado,
            alPresionar: pmt > 0 ? () => _guardar(pmt, ahorro) : null,
          ),
          const SizedBox(height: 16),
        ] else ...[
          TarjetaPF(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EtiquetaSeccion('Periodo ${p!.textoPeriodo}'),
                FilaDato('PMT', dinero(p!.pmt)),
                FilaDato('Ahorro reservado', dinero(p!.ahorroReservado)),
                FilaDato('Saldo disponible', dinero(p!.saldo)),
                FilaDato('Gastado', dinero(p!.gastado)),
                FilaDato('Estado', p!.textoEstado,
                    colorValor: colorEstado(p!.idEstado)),
                FilaDato('Vigencia',
                    '${fechaCorta(p!.fechaInicio)} al ${fechaCorta(p!.fechaFin)}'),
              ],
            ),
          ),
          const CajaMensaje(
            nivel: NivelMensaje.info,
            texto:
                'Los fondos de este periodo ya están configurados. Podrás definir nuevos fondos después del corte de caja.',
          ),
        ],
        FutureBuilder<CorteCaja?>(
          future: _futuroCorte,
          builder: (context, s) {
            final c = s.data;
            return GestureDetector(
              onLongPress: _forzarCorte,
              child: TarjetaPF(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EtiquetaSeccion('Cortes de caja'),
                    Text(
                      c == null
                          ? 'Aún no se ha ejecutado ningún corte. Se realiza automáticamente al terminar el mes.'
                          : 'Último corte: ${c.periodoTexto} · ${fechaHoraLarga(c.fechaHora)}',
                      style: const TextStyle(color: Colores.texto),
                    ),
                    if (c != null) ...[
                      const SizedBox(height: 12),
                      BotonPF(
                        texto: 'Ver reporte',
                        tipo: TipoBoton.secundario,
                        compacto: true,
                        alPresionar: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => PantallaCorte(corte: c))),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                        'Demo: mantén presionada esta tarjeta para forzar el corte.',
                        style: TextStyle(color: Colores.gris, fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}