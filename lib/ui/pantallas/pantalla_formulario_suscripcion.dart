import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import '../../modelos/suscripcion.dart';
import '../../servicios/servicio_suscripcion.dart';

/// Sirve para agregar (existente == null) y para editar.
class PantallaFormularioSuscripcion extends StatefulWidget {
  final Suscripcion? existente;
  const PantallaFormularioSuscripcion({super.key, this.existente});

  @override
  State<PantallaFormularioSuscripcion> createState() =>
      _PantallaFormularioSuscripcionState();
}

class _PantallaFormularioSuscripcionState
    extends State<PantallaFormularioSuscripcion> {
  late final TextEditingController _nombre;
  late final TextEditingController _monto;
  late final TextEditingController _dia;
  int _tipo = 1;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _monto = TextEditingController(text: e == null ? '' : e.monto.toString());
    _dia = TextEditingController(text: e?.diaCobro.toString() ?? '');
    _tipo = e?.idTipo ?? 1;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    _dia.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty ||
        _monto.text.trim().isEmpty ||
        _dia.text.trim().isEmpty) {
      setState(() =>
          _error = 'Completa los campos marcados con * para continuar.');
      return;
    }

    final idUsuario = context.read<EstadoApp>().idUsuario!;
    final monto = double.tryParse(_monto.text) ?? 0;
    final dia = int.tryParse(_dia.text) ?? 0;
    final servicio = ServicioSuscripcion();

    setState(() {
      _guardando = true;
      _error = null;
    });

    String? error;
    try {
      error = widget.existente == null
          ? await servicio.crear(
              idUsuario: idUsuario,
              nombre: _nombre.text,
              monto: monto,
              idTipo: _tipo,
              diaCobro: dia)
          : await servicio.editar(
              idUsuario: idUsuario,
              id: widget.existente!.id,
              nombre: _nombre.text,
              monto: monto,
              idTipo: _tipo,
              diaCobro: dia);
    } catch (_) {
      error = 'No fue posible guardar la información. Intenta nuevamente.';
    }

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _guardando = false;
      });
      return;
    }
    Navigator.pop(context, true); // true = se guardó
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(editando ? 'Editar suscripción' : 'Agregar suscripción')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('* Campo obligatorio'),
          const SizedBox(height: 12),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Nombre *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: const InputDecoration(
                labelText: 'Monto mensual *',
                prefixText: '\$ ',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dia,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: const InputDecoration(
                labelText: 'Día de cobro del mes (1 a 31) *',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Tipo de suscripción *'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Ocio y consumo')),
              ButtonSegment(value: 2, label: Text('Servicios y hogar')),
            ],
            selected: {_tipo},
            onSelectionChanged: (valor) => setState(() => _tipo = valor.first),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(editando ? 'Guardar cambios' : 'Agregar suscripción'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
        ],
      ),
    );
  }
}