// Test básico de la app de reserva de plazas de garaje.
//
// Comprueba el flujo principal: una plaza libre se puede reservar
// introduciendo un nombre, y una plaza ocupada se libera al pulsarla.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibecode_garage/main.dart';

void main() {
  testWidgets('reservar y liberar una plaza de garaje', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GarageBookingApp());

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
