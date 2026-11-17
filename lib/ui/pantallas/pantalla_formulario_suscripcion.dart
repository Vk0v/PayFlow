import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/suscripcion.dart';
import 'package:payflow/servicios/servicio_suscripcion.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';
import 'package:payflow/ui/widgets/encabezado.dart';

class PantallaFormularioSuscripcion extends StatefulWidget {
  final Suscripcion? suscripcion;
  const PantallaFormularioSuscripcion({super.key, this.suscripcion});

  @override
  State<PantallaFormularioSuscripcion> createState() => _EstadoFormulario();
}

class _EstadoFormulario extends State<PantallaFormularioSuscripcion> {
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  int _tipo = 1;
  int? _dia;
  bool _auto = false;
  bool _ocupado = false;
  bool _intentoGuardar = false;
  bool _cambios = false;

  bool get _edita => widget.suscripcion != null;

  @override
  void initState() {
    super.initState();
    final s = widget.suscripcion;
    if (s != null) {
      _nombre.text = s.nombre;
      _monto.text = s.monto.toStringAsFixed(2);
      _tipo = s.idTipo;
      _dia = s.diaCobro;
      _auto = s.autocobro;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  List<String> get _pendientes {
    final l = <String>[];
    if (_nombre.text.trim().isEmpty) l.add('Nombre');
    final m = double.tryParse(_monto.text.trim());
    if (m == null || m <= 0) l.add('Monto');
    if (_dia == null) l.add('Día de cobro');
    return l;
  }

  Future<bool> _confirmarSalida() async {
    if (!_cambios) return true;
    return mostrarConfirmacion(
      context,
      titulo: '¿Descartar cambios?',
      mensaje: 'Los datos capturados se perderán.',
      textoSi: 'Descartar',
      textoNo: 'Seguir editando',
      peligro: true,
    );
  }

  Future<void> _cancelar() async {
    if (await _confirmarSalida() && mounted) Navigator.pop(context, false);
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    if (_pendientes.isNotEmpty) return;
    final nombre = _nombre.text.trim();
    final monto = double.parse(_monto.text.trim());
    final ok = await mostrarConfirmacion(
      context,
      titulo: _edita ? '¿Guardar cambios?' : '¿Confirmar suscripción?',
      mensaje:
          '**$nombre** por **${dinero(monto)}**, cobro el día **$_dia** de cada mes${_auto ? ', con autodébito' : ''}.',
      textoSi: 'Confirmar',
    );
    if (!ok || !mounted) return;
    setState(() => _ocupado = true);
    final id = context.read<EstadoApp>().idUsuario!;
    if (_edita) {
      await ServicioSuscripcion.editar(widget.suscripcion!.id,
          nombre: nombre, monto: monto, idTipo: _tipo, dia: _dia!, autocobro: _auto);
    } else {
      await ServicioSuscripcion.crear(id,
          nombre: nombre, monto: monto, idTipo: _tipo, dia: _dia!, autocobro: _auto);
    }
    if (!mounted) return;
    context.read<EstadoApp>().notificarCambio();
    await mostrarAviso(context,
        titulo: _edita ? 'Suscripción actualizada' : 'Suscripción registrada',
        mensaje: '**$nombre** quedó guardada.');
    if (mounted) {
      _cambios = false;
      Navigator.pop(context, true);
    }
  }

  Future<void> _reactivar() async {
    await ServicioSuscripcion.reactivar(widget.suscripcion!.id);
    if (!mounted) return;
    context.read<EstadoApp>().notificarCambio();
    Navigator.pop(context, true);
  }

  Widget _celdaDia(int d, bool habilitado) {
    final sel = _dia == d;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: habilitado
          ? () => setState(() {
                _dia = d;
                _cambios = true;
              })
          : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel
              ? Colores.marino
              : (habilitado ? Colors.white : Colores.grisClaro),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colores.borde),
        ),
        child: Text('$d',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel
                    ? Colors.white
                    : (habilitado ? Colores.texto : Colores.gris.withOpacity(0.5)))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().day;
    final diaActual = widget.suscripcion?.diaCobro;
    final pendientes = _pendientes;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmarSalida,
      child: Scaffold(
        appBar: EncabezadoPF(
            subtitulo: _edita ? 'Editar suscripción' : 'Nueva suscripción',
            atras: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TarjetaPF(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoPF(
                      etiqueta: 'Nombre',
                      controlador: _nombre,
                      hint: 'Ej. Netflix',
                      alCambiar: (_) => setState(() => _cambios = true)),
                  CampoPF(
                      etiqueta: 'Monto mensual',
                      controlador: _monto,
                      prefijo: '\$ ',
                      teclado: const TextInputType.numberWithOptions(decimal: true),
                      formatos: [soloMonto],
                      alCambiar: (_) => setState(() => _cambios = true)),
                  const EtiquetaSeccion('Tipo de suscripción'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final t in [
                        [1, 'Ocio y consumo'],
                        [2, 'Servicios y hogar']
                      ])
                        ChoiceChip(
                          label: Text(t[1] as String),
                          selected: _tipo == t[0],
                          selectedColor: Colores.marino,
                          labelStyle: TextStyle(
                              color: _tipo == t[0] ? Colors.white : Colores.texto,
                              fontWeight: FontWeight.w600),
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            _tipo = t[0] as int;
                            _cambios = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const EtiquetaSeccion('Día de cobro'),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var d = 1; d <= 31; d++)
                        _celdaDia(d, d >= hoy || d == diaActual),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Los días anteriores a hoy no están disponibles.',
                      style: TextStyle(color: Colores.gris, fontSize: 11)),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: _auto,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colores.marino,
                    title: const Text('Autodébito',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Cobrar automáticamente en la fecha de pago si hay saldo suficiente.',
                        style: TextStyle(fontSize: 12)),
                    onChanged: (v) => setState(() {
                      _auto = v ?? false;
                      _cambios = true;
                    }),
                  ),
                ],
              ),
            ),
            if (_intentoGuardar) CajaCamposPendientes(pendientes),
            BotonPF(
                texto: _edita ? 'Guardar cambios' : 'Guardar suscripción',
                ocupado: _ocupado,
                alPresionar: _guardar),
            const SizedBox(height: 10),
            if (_edita && widget.suscripcion!.suspendida) ...[
              BotonPF(
                  texto: 'Reactivar suscripción',
                  tipo: TipoBoton.verde,
                  alPresionar: _reactivar),
              const SizedBox(height: 10),
            ],
            BotonPF(
                texto: 'Cancelar',
                tipo: TipoBoton.secundario,
                alPresionar: _cancelar),
          ],
        ),
      ),
    );
  }
}