import 'dart:async';

import 'package:flutter/material.dart';

import 'garage_api.dart';

void main() {
  runApp(GarageBookingApp());
}

/// Widget raíz de la app. Define el tema general y la pantalla de inicio.
///
/// Acepta un [api] opcional para poder sustituir el cliente HTTP real por
/// uno de prueba en los tests, sin tocar el resto de la app.
class GarageBookingApp extends StatelessWidget {
  GarageBookingApp({super.key, GarageApi? api}) : api = api ?? GarageApi();

  final GarageApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reserva de Garaje',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: ParkingSpotsPage(api: api),
    );
  }
}

/// Representa el estado de una plaza tal y como lo devuelve la API: su id
/// (necesario para poder ocuparla o liberarla), su nombre (P1, P2...) y,
/// si está ocupada, el nombre de la persona que la reservó.
class ParkingSpot {
  ParkingSpot({required this.id, required this.name, this.occupiedBy});

  factory ParkingSpot.fromJson(Map<String, dynamic> json) => ParkingSpot(
    id: json['id'] as int,
    name: json['nombre'] as String,
    occupiedBy: json['ocupado_por'] as String?,
  );

  final int id;
  final String name;
  String? occupiedBy;

  bool get isOccupied => occupiedBy != null;
}

/// Pantalla principal: lista de plazas con su estado actual, obtenido del
/// backend real. `api` se puede sustituir (por ejemplo en tests) para no
/// depender de la red de verdad.
class ParkingSpotsPage extends StatefulWidget {
  ParkingSpotsPage({super.key, GarageApi? api}) : api = api ?? GarageApi();

  final GarageApi api;

  @override
  State<ParkingSpotsPage> createState() => _ParkingSpotsPageState();
}

class _ParkingSpotsPageState extends State<ParkingSpotsPage> {
  List<ParkingSpot> _spots = [];

  // _isLoading cubre tanto la carga inicial como cualquier acción sobre una
  // plaza (ocupar/liberar): mientras esté a true, se bloquea la interacción
  // y se muestra un indicador, para no disparar dos peticiones a la vez.
  bool _isLoading = true;
  bool _isSlow = false;
  String? _errorInicial;

  @override
  void initState() {
    super.initState();
    _cargarPlazas();
  }

  /// Ejecuta [accion] mostrando un indicador de carga, y si tarda más de
  /// unos segundos añade el aviso de "conectando..." (pensado para cuando
  /// Render tiene que despertar el servicio, algo que puede tardar hasta
  /// medio minuto). Devuelve el resultado, o null si algo falla.
  Future<T?> _conIndicadorDeCarga<T>(Future<T> Function() accion) async {
    setState(() {
      _isLoading = true;
      _isSlow = false;
    });
    final avisoLento = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isSlow = true);
    });
    try {
      return await accion();
    } catch (e) {
      _mostrarError(e is GarageApiException ? e.message : 'Ha ocurrido un error inesperado.');
      return null;
    } finally {
      avisoLento.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSlow = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cargarPlazas() async {
    setState(() => _errorInicial = null);
    final datos = await _conIndicadorDeCarga(widget.api.obtenerPlazas);
    if (datos != null) {
      setState(() => _spots = datos.map(ParkingSpot.fromJson).toList());
    } else if (_spots.isEmpty) {
      setState(() => _errorInicial = 'No se pudo cargar el estado de las plazas.');
    }
  }

  /// Se ejecuta al pulsar una plaza. Si está libre, pide el nombre y la
  /// ocupa; si está ocupada, la libera directamente sin confirmación.
  Future<void> _onSpotTapped(ParkingSpot spot) async {
    if (spot.isOccupied) {
      final actualizada = await _conIndicadorDeCarga(
        () => widget.api.liberarPlaza(spot.id),
      );
      if (actualizada != null) {
        setState(() => spot.occupiedBy = null);
      }
      return;
    }

    final name = await _askForName(spot.name);
    if (name == null || name.trim().isEmpty) return;

    final actualizada = await _conIndicadorDeCarga(
      () => widget.api.ocuparPlaza(spot.id, name.trim()),
    );
    if (actualizada != null) {
      setState(() => spot.occupiedBy = name.trim());
    }
  }

  /// Muestra un diálogo con un campo de texto para introducir el nombre
  /// de quien reserva la plaza. Devuelve el texto introducido, o null si
  /// se cancela.
  Future<String?> _askForName(String spotName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Reservar $spotName'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Introduce tu nombre',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Reservar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plazas de garaje'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _isLoading ? null : _cargarPlazas,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorInicial != null) {
      return _buildEstadoDeError();
    }
    if (_isLoading && _spots.isEmpty) {
      return _buildIndicadorDeCarga();
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _spots.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final spot = _spots[index];
            return _ParkingSpotTile(
              spot: spot,
              onTap: _isLoading ? null : () => _onSpotTapped(spot),
            );
          },
        ),
        if (_isLoading) _buildSuperposicionDeCarga(),
      ],
    );
  }

  Widget _buildIndicadorDeCarga() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (_isSlow) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Conectando con el servidor...\nSi llevaba un rato dormido, '
                'puede tardar hasta medio minuto.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Capa semitransparente que se pone encima de la lista mientras hay una
  /// acción en curso (ocupar/liberar/refrescar), para bloquear más toques.
  Widget _buildSuperposicionDeCarga() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.2),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_isSlow ? 'Conectando con el servidor...' : 'Cargando...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoDeError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorInicial!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargarPlazas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta que representa una plaza en la lista: color verde/rojo según
/// su estado, y el nombre de quien la ocupa si aplica.
class _ParkingSpotTile extends StatelessWidget {
  const _ParkingSpotTile({required this.spot, required this.onTap});

  final ParkingSpot spot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = spot.isOccupied ? Colors.red : Colors.green;

    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Text(
                  spot.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      spot.isOccupied
                          ? 'Ocupada por ${spot.occupiedBy}'
                          : 'Libre',
                      style: TextStyle(color: color),
                    ),
                  ],
                ),
              ),
              Icon(
                spot.isOccupied ? Icons.lock : Icons.lock_open,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
