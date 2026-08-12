import 'package:flutter/material.dart';

void main() {
  runApp(const GarageBookingApp());
}

/// Widget raíz de la app. Define el tema general y la pantalla de inicio.
class GarageBookingApp extends StatelessWidget {
  const GarageBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reserva de Garaje',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ParkingSpotsPage(),
    );
  }
}

/// Representa el estado de una plaza de garaje: su nombre (P1, P2...)
/// y, si está ocupada, el nombre de la persona que la reservó.
class ParkingSpot {
  ParkingSpot({required this.name, this.occupiedBy});

  final String name;
  String? occupiedBy;

  bool get isOccupied => occupiedBy != null;
}

/// Pantalla principal: lista de las 5 plazas con su estado actual.
/// Es un StatefulWidget porque el estado de las plazas cambia en memoria
/// mientras la app está abierta (no se guarda en ningún sitio).
class ParkingSpotsPage extends StatefulWidget {
  const ParkingSpotsPage({super.key});

  @override
  State<ParkingSpotsPage> createState() => _ParkingSpotsPageState();
}

class _ParkingSpotsPageState extends State<ParkingSpotsPage> {
  final List<ParkingSpot> _spots = List.generate(
    5,
    (index) => ParkingSpot(name: 'P${index + 1}'),
  );

  /// Se ejecuta al pulsar una plaza. Si está libre, pide el nombre y la
  /// ocupa; si está ocupada, la libera directamente sin confirmación.
  Future<void> _onSpotTapped(ParkingSpot spot) async {
    if (spot.isOccupied) {
      setState(() => spot.occupiedBy = null);
      return;
    }

    final name = await _askForName(spot.name);
    if (name != null && name.trim().isNotEmpty) {
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
      appBar: AppBar(title: const Text('Plazas de garaje')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _spots.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return _ParkingSpotTile(
            spot: spot,
            onTap: () => _onSpotTapped(spot),
          );
        },
      ),
    );
  }
}

/// Tarjeta que representa una plaza en la lista: color verde/rojo según
/// su estado, y el nombre de quien la ocupa si aplica.
class _ParkingSpotTile extends StatelessWidget {
  const _ParkingSpotTile({required this.spot, required this.onTap});

  final ParkingSpot spot;
  final VoidCallback onTap;

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
