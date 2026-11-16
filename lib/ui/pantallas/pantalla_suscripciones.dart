import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import '../../modelos/suscripcion.dart';
import '../../servicios/servicio_suscripcion.dart';
import '../../utilidades/formato.dart';
import 'pantalla_formulario_suscripcion.dart';

class PantallaSuscripciones extends StatefulWidget {
  const PantallaSuscripciones({super.key});

  @override
  State<PantallaSuscripciones> createState() => _PantallaSuscripcionesState();
}

class _PantallaSuscripcionesState extends State<PantallaSuscripciones> {
  late Future<List<Suscripcion>> _futuro;
  int _revisionVista = -1;
  final _servicio = ServicioSuscripcion();

  Color _colorEstado(int? idEstado) => switch (idEstado) {
        1 => Colors.orange,
        2 => Colors.green,
        3 => Colors.red,
        4 => Colors.grey,
        _ => Colors.blueGrey,
      };

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    return respuesta == true;
  }

  Future<void> _abrirFormulario({Suscripcion? existente}) async {
    final estadoApp = context.read<EstadoApp>();
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => PantallaFormularioSuscripcion(existente: existente)),
    );
    if (guardado == true) estadoApp.notificarCambio();
  }

  Future<void> _pagarAhora(Suscripcion s) async {
    final estadoApp = context.read<EstadoApp>();
    final mensajero = ScaffoldMessenger.of(context);
    final seguro = await _confirmar('¿Pagar ahora?',
        'Se descontarán ${dinero(s.monto)} de tu saldo disponible por "${s.nombre}".');
    if (!seguro) return;

    final resultado = await _servicio.cobrar(s.idCobro!);
    estadoApp.notificarCambio();
    mensajero.showSnackBar(SnackBar(
      content: Text(switch (resultado) {
        ResultadoCobro.pagado => 'Pago registrado: ${dinero(s.monto)}.',
        ResultadoCobro.rechazado =>
          'Saldo insuficiente. La suscripción quedó vencida.',
        ResultadoCobro.noAplica => 'Este cobro ya no se puede pagar.',
      }),
    ));
  }

  Future<void> _cambiarSuspension(Suscripcion s) async {
    final estadoApp = context.read<EstadoApp>();
    final seguro = await _confirmar(
        s.suspendida ? '¿Reactivar suscripción?' : '¿Suspender suscripción?',
        s.suspendida
            ? '"${s.nombre}" volverá a cobrarse en su fecha.'
            : '"${s.nombre}" no se cobrará mientras esté suspendida.');
    if (!seguro) return;

    if (s.suspendida) {
      await _servicio.reactivar(s.id);
    } else {
      await _servicio.suspender(s.id);
    }
    estadoApp.notificarCambio();
  }

  Future<void> _eliminar(Suscripcion s) async {
    final estadoApp = context.read<EstadoApp>();
    final seguro = await _confirmar('¿Eliminar suscripción?',
        'Se eliminará "${s.nombre}" y sus cobros pendientes. Esta acción no se puede deshacer.');
    if (!seguro) return;

    await _servicio.eliminar(s.id);
    estadoApp.notificarCambio();
  }

  void _mostrarDetalle(Suscripcion s) {
    showModalBottomSheet(
      context: context,
      builder: (hoja) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.nombre,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Monto: ${dinero(s.monto)}'),
              Text('Tipo: ${s.textoTipo}'),
              Text('Día de cobro: ${s.diaCobro}'),
              if (s.fechaCobro != null)
                Text('Próximo cobro: ${fechaLegible(s.fechaCobro!)}'),
              Text('Estado: ${s.textoEstado}'),
              const SizedBox(height: 12),
              if (s.sePuedePagar)
                FilledButton(
                    onPressed: () {
                      Navigator.pop(hoja);
                      _pagarAhora(s);
                    },
                    child: const Text('Pagar ahora')),
              OutlinedButton(
                  onPressed: () {
                    Navigator.pop(hoja);
                    _abrirFormulario(existente: s);
                  },
                  child: const Text('Editar')),
              OutlinedButton(
                  onPressed: () {
                    Navigator.pop(hoja);
                    _cambiarSuspension(s);
                  },
                  child: Text(s.suspendida ? 'Reactivar' : 'Suspender')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(hoja);
                    _eliminar(s);
                  },
                  child: const Text('Eliminar',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actualizar() async {
    final estadoApp = context.read<EstadoApp>();
    await _servicio.procesarCobrosPendientes(estadoApp.idUsuario!);
    estadoApp.notificarCambio();
  }

  @override
  Widget build(BuildContext context) {
    final estadoApp = context.watch<EstadoApp>();
    if (estadoApp.revision != _revisionVista) {
      _revisionVista = estadoApp.revision;
      _futuro = _servicio.listar(estadoApp.idUsuario!);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder<List<Suscripcion>>(
        future: _futuro,
        builder: (context, instantanea) {
          if (instantanea.hasError) {
            return const Center(
                child: Text('No fue posible consultar tus suscripciones.'));
          }
          if (!instantanea.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = instantanea.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Aún no tienes suscripciones registradas.\nToca "Agregar" para registrar la primera.',
                    textAlign: TextAlign.center),
              ),
            );
          }

          final totalMensual = lista
              .where((s) => !s.suspendida)
              .fold<double>(0, (suma, s) => suma + s.monto);

          return RefreshIndicator(
            onRefresh: _actualizar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Total mensual en suscripciones'),
                    trailing: Text(dinero(totalMensual),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                for (final s in lista)
                  Card(
                    child: ListTile(
                      onTap: () => _mostrarDetalle(s),
                      title: Text(s.nombre),
                      subtitle: Text(
                          '${dinero(s.monto)} · día ${s.diaCobro} · ${s.textoTipo}'),
                      trailing: Chip(
                        label: Text(s.textoEstado,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        backgroundColor: _colorEstado(s.idEstadoCobro),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}