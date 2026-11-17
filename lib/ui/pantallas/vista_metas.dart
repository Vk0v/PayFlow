import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/meta.dart';
import 'package:payflow/servicios/servicio_meta.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';
import 'package:payflow/ui/pantallas/dialogos_metas.dart';

class VistaMetas extends StatefulWidget {
  const VistaMetas({super.key});

  @override
  State<VistaMetas> createState() => _EstadoMetas();
}

class _EstadoMetas extends State<VistaMetas> {
  Future<List<Object>>? _futuro;
  int _revisionVista = -1;

  void _avisar() => context.read<EstadoApp>().notificarCambio();

  Future<void> _nueva() async {
    final ok = await mostrarNuevaMeta(context);
    if (!ok || !mounted) return;
    _avisar();
    await mostrarAviso(context,
        titulo: 'Meta guardada', mensaje: 'Tu meta de ahorro quedó registrada.');
  }

  Future<void> _aportar(Meta m, double disponible) async {
    final ok = await mostrarAportar(context, m, disponible);
    if (!ok || !mounted) return;
    _avisar();
    await mostrarAviso(context,
        titulo: 'Aportación registrada',
        mensaje: 'Se aportó a **${m.nombre}** correctamente.');
  }

  Future<void> _eliminar(Meta m) async {
    final ok = await mostrarConfirmacion(
      context,
      titulo: '¿Eliminar meta?',
      mensaje: 'Se eliminará la meta **${m.nombre}**. Esta acción no se puede deshacer.',
      textoSi: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await ServicioMeta.eliminar(m.id);
    if (mounted) _avisar();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (_futuro == null || _revisionVista != app.revision) {
      _revisionVista = app.revision;
      final id = app.idUsuario!;
      _futuro = Future.wait<Object>(
          [ServicioMeta.listar(id), ServicioMeta.ahorroDisponible(id)]);
    }
    return FutureBuilder<List<Object>>(
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
        final metas = snap.data![0] as List<Meta>;
        final disponible = snap.data![1] as double;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TarjetaPF(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EtiquetaSeccion('Ahorro disponible del periodo'),
                  Text(dinero(disponible),
                      style:
                          const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const Text('Monto que aún puedes aportar a tus metas',
                      style: TextStyle(color: Colores.gris, fontSize: 12)),
                ],
              ),
            ),
            BotonPF(texto: 'Nueva meta', icono: Icons.add, alPresionar: _nueva),
            const SizedBox(height: 16),
            const EtiquetaSeccion('Tus metas'),
            if (metas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Aún no tienes metas de ahorro.',
                    style: TextStyle(color: Colores.gris)),
              ),
            for (final m in metas)
              TarjetaPF(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconoCuadro(Icons.flag_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(
                                  '${dinero(m.acumulado)} de ${dinero(m.objetivo)}',
                                  style: const TextStyle(
                                      color: Colores.gris, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colores.rojo),
                          onPressed: () => _eliminar(m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    BarraProgreso(valor: m.progreso),
                    if (m.fechaLimite != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Fecha límite: ${fechaLarga(m.fechaLimite!)}',
                            style: const TextStyle(
                                color: Colores.gris, fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: BotonPF(
                              texto: 'Aportar',
                              compacto: true,
                              alPresionar: () => _aportar(m, disponible)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BotonPF(
                              texto: 'Aportaciones',
                              tipo: TipoBoton.secundario,
                              compacto: true,
                              alPresionar: () => mostrarAportaciones(context, m)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}