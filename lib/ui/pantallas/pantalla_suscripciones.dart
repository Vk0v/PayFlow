import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/suscripcion.dart';
import 'package:payflow/servicios/servicio_suscripcion.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';
import 'package:payflow/ui/pantallas/pantalla_formulario_suscripcion.dart';

class PantallaSuscripciones extends StatefulWidget {
  const PantallaSuscripciones({super.key});

  @override
  State<PantallaSuscripciones> createState() => _EstadoSuscripciones();
}

class _EstadoSuscripciones extends State<PantallaSuscripciones> {
  Future<List<Suscripcion>>? _futuro;
  int _revisionVista = -1;

  void _avisar() => context.read<EstadoApp>().notificarCambio();

  Future<void> _agregar() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const PantallaFormularioSuscripcion()));
  }

  Future<void> _pagar(Suscripcion s) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Pagar suscripción?',
      mensaje:
          'Se descontarán **${dinero(s.monto)}** de tu saldo disponible por **${s.nombre}**.',
      textoSi: 'Pagar ahora',
    );
    if (!ok || !mounted) return;
    final r = await ServicioSuscripcion.cobrar(s.idSp!);
    if (!mounted) return;
    _avisar();
    if (r == ResultadoCobro.pagado) {
      await mostrarAviso(context,
          titulo: 'Pago registrado',
          mensaje: 'Se pagó **${s.nombre}** correctamente.');
    } else if (r == ResultadoCobro.rechazado) {
      await mostrarAviso(context,
          titulo: 'Saldo insuficiente',
          mensaje:
              'No se pudo cobrar **${s.nombre}**: tu saldo disponible no cubre ${dinero(s.monto)}.',
          icono: Icons.error_outline,
          color: Colores.rojo);
    } else {
      await mostrarAviso(context,
          titulo: 'No se puede pagar',
          mensaje:
              'Esta suscripción no puede cobrarse ahora. Revisa que tus fondos estén configurados y sin déficit.',
          icono: Icons.info_outline,
          color: Colores.ambar);
    }
  }

  Future<void> _suspender(Suscripcion s) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Suspender suscripción?',
      mensaje:
          '**${s.nombre}** dejará de cobrarse mientras esté suspendida. Podrás reactivarla cuando quieras.',
      textoSi: 'Suspender',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await ServicioSuscripcion.suspender(s.id);
    if (mounted) _avisar();
  }

  Future<void> _reactivar(Suscripcion s) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Reactivar suscripción?',
      mensaje: '**${s.nombre}** volverá a cobrarse en su fecha de pago.',
      textoSi: 'Reactivar',
    );
    if (!ok || !mounted) return;
    await ServicioSuscripcion.reactivar(s.id);
    if (mounted) _avisar();
  }

  Future<void> _eliminar(Suscripcion s) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Eliminar suscripción?',
      mensaje:
          'Se dará de baja **${s.nombre}**. Los cobros ya realizados se conservan en tu historial.',
      textoSi: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await ServicioSuscripcion.eliminar(s.id);
    if (mounted) _avisar();
  }

  Future<void> _detalle(Suscripcion s) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => VentanaPF(
        titulo: s.nombre,
        icono: Icons.autorenew,
        contenido: Column(
          children: [
            FilaDato('Monto', dinero(s.monto)),
            FilaDato('Tipo', s.tipo),
            FilaDato('Día de cobro', 'Día ${s.diaCobro} de cada mes'),
            if (s.fechaProgramada != null)
              FilaDato('Próximo cobro', fechaLarga(s.fechaProgramada!)),
            FilaDato('Autodébito', s.autocobro ? 'Activado' : 'Desactivado'),
            FilaDato('Estado', s.textoEstado),
            if (s.intentos > 0) FilaDato('Intentos de cobro', '${s.intentos}'),
          ],
        ),
        acciones: [
          BotonPF(
            texto: 'Editar',
            icono: Icons.edit_outlined,
            alPresionar: () {
              Navigator.pop(ctx);
              Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => PantallaFormularioSuscripcion(suscripcion: s)));
            },
          ),
          BotonPF(
            texto: 'Eliminar',
            tipo: TipoBoton.peligro,
            icono: Icons.delete_outline,
            alPresionar: () {
              Navigator.pop(ctx);
              _eliminar(s);
            },
          ),
          BotonPF(
              texto: 'Cerrar',
              tipo: TipoBoton.secundario,
              alPresionar: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (_futuro == null || _revisionVista != app.revision) {
      _revisionVista = app.revision;
      _futuro = ServicioSuscripcion.listar(app.idUsuario!);
    }
    return FutureBuilder<List<Suscripcion>>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            CajaMensaje(nivel: NivelMensaje.error, texto: 'Error: ${snap.error}'),
          ]);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = snap.data!;
        final activas = lista.where((s) => !s.suspendida).toList();
        final compromiso = activas.fold<double>(0, (a, s) => a + s.monto);
        final proximos =
            lista.where((s) => s.pendiente && s.fechaProgramada != null).take(3).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TarjetaPF(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetaSeccion('Compromiso mensual'),
                  Text(dinero(compromiso),
                      style:
                          const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  Text('${activas.length} suscripciones activas',
                      style: const TextStyle(color: Colores.gris, fontSize: 12)),
                ],
              ),
            ),
            BotonPF(
                texto: 'Agregar suscripción', icono: Icons.add, alPresionar: _agregar),
            const SizedBox(height: 16),
            TarjetaPF(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetaSeccion('Próximos cobros'),
                  if (proximos.isEmpty)
                    const Text('No tienes cobros pendientes este periodo.',
                        style: TextStyle(color: Colores.gris)),
                  for (final s in proximos)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                    '${textoDias(diasHasta(s.fechaProgramada!))} · ${diaYMes(s.fechaProgramada!)}',
                                    style: const TextStyle(
                                        color: Colores.gris, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(dinero(s.monto),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const EtiquetaSeccion('Tus suscripciones'),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Aún no registras suscripciones.',
                    style: TextStyle(color: Colores.gris)),
              ),
            for (final s in lista) _tarjeta(s),
          ],
        );
      },
    );
  }

  Widget _tarjeta(Suscripcion s) {
    Color color = Colores.ambar;
    Color fondo = Colores.ambarClaro;
    if (s.suspendida) {
      color = Colores.gris;
      fondo = Colores.grisClaro;
    } else if (s.pagada) {
      color = Colores.verde;
      fondo = Colores.verdeClaro;
    } else if (s.vencida) {
      color = Colores.rojo;
      fondo = Colores.rojoClaro;
    }
    return TarjetaPF(
      alTocar: () => _detalle(s),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoCuadro(Icons.autorenew),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${dinero(s.monto)} · día ${s.diaCobro}',
                        style: const TextStyle(color: Colores.gris, fontSize: 12)),
                  ],
                ),
              ),
              EtiquetaEstado(s.textoEstado, color, fondo),
            ],
          ),
          if (s.autocobro)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EtiquetaEstado('Autodébito', Colores.azul, Colores.azulClaro),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (s.puedePagar) ...[
                Expanded(
                  child: BotonPF(
                      texto: 'Pagar ahora',
                      compacto: true,
                      alPresionar: () => _pagar(s)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: s.suspendida
                    ? BotonPF(
                        texto: 'Reactivar',
                        tipo: TipoBoton.verde,
                        compacto: true,
                        alPresionar: () => _reactivar(s))
                    : BotonPF(
                        texto: 'Suspender',
                        tipo: TipoBoton.secundario,
                        compacto: true,
                        alPresionar: () => _suspender(s)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}