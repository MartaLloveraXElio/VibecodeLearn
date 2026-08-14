// Test de la app de reserva de plazas de garaje.
//
// La pantalla ya no guarda el estado en memoria: lo pide a la API real.
// Para probarla sin depender de la red, se sustituye el cliente HTTP por
// un MockClient que simula las respuestas del backend.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vibecode_garage/garage_api.dart';
import 'package:vibecode_garage/main.dart';

Map<String, dynamic> _plaza(int id, {String? ocupadoPor}) => {
  'id': id,
  'nombre': 'P$id',
  'ocupada': ocupadoPor != null,
  'ocupado_por': ocupadoPor,
  'created_at': '2026-01-01T00:00:00Z',
};

void main() {
  testWidgets('carga las plazas, reserva P1 y luego la libera', (
    WidgetTester tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/plazas') {
        final plazas = List.generate(5, (i) => _plaza(i + 1));
        return http.Response(jsonEncode(plazas), 200);
      }
      if (request.method == 'PUT' && request.url.path == '/plazas/1/ocupar') {
        final nombre = jsonDecode(request.body)['nombre'] as String;
        return http.Response(jsonEncode(_plaza(1, ocupadoPor: nombre)), 200);
      }
      if (request.method == 'PUT' &&
          request.url.path == '/plazas/1/liberar') {
        return http.Response(jsonEncode(_plaza(1)), 200);
      }
      return http.Response('No encontrado', 404);
    });

    await tester.pumpWidget(GarageBookingApp(api: GarageApi(client: client)));
    await tester.pumpAndSettle();

    // Al principio todas las plazas están libres.
    expect(find.text('Libre'), findsNWidgets(5));

    // Pulsar la primera plaza (P1) abre el diálogo para pedir el nombre.
    await tester.tap(find.text('P1').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Marta');
    await tester.tap(find.text('Reservar'));
    await tester.pumpAndSettle();

    // La plaza queda ocupada mostrando el nombre introducido.
    expect(find.text('Ocupada por Marta'), findsOneWidget);
    expect(find.text('Libre'), findsNWidgets(4));

    // Pulsar la plaza ocupada la libera de nuevo.
    await tester.tap(find.text('P1').first);
    await tester.pumpAndSettle();

    expect(find.text('Ocupada por Marta'), findsNothing);
    expect(find.text('Libre'), findsNWidgets(5));
  });
}
