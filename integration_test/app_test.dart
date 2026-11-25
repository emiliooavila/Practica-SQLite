import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';
import 'package:integration_test/integration_test.dart';

/// Prueba de integración en una plataforma de escritorio real.
///
/// Usa la base persistente de la app (la misma que abre `AppDatabase.archivo`)
/// y recorre P1-P5 desde la interfaz. Deja dos tareas con el prefijo
/// "Prueba Linux" para poder comprobar la persistencia al reabrir la app;
/// una nueva ejecución las elimina antes de empezar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P1-P5 y persistencia al reabrir la base en Linux', (tester) async {
    final db = AppDatabase.archivo();
    await db.customStatement(
      "DELETE FROM tareas WHERE titulo LIKE 'Prueba Linux%'",
    );

    /// En un dispositivo real las escrituras son asíncronas de verdad:
    /// hay que esperar a que la interfaz refleje cada cambio.
    Future<void> esperarHasta(bool Function() condicion) async {
      for (var intento = 0; intento < 100; intento++) {
        if (condicion()) return;
        await tester.pump(const Duration(milliseconds: 50));
      }
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((texto) => texto.data)
          .toList();
      final campo =
          tester.widget<TextField>(find.byType(TextField)).controller?.text;
      final filas = await db.obtenerTareas();
      fail('La interfaz no llegó al estado esperado. '
          'campo=$campo textos=$textos filas=$filas');
    }

    bool campoVacio() =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text.isEmpty;

    Future<void> agregar(String titulo) async {
      // En un dispositivo real hay que enfocar el campo antes de escribir;
      // si no, el segundo enterText no llega al motor de texto.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), titulo);
      await tester.tap(find.text('Agregar tarea'));
      await esperarHasta(
        () => campoVacio() && find.text(titulo).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pumpAndSettle();

    // P1: tres altas y comprobación tras cerrar y reabrir la app.
    await agregar('Prueba Linux alta 1');
    await agregar('Prueba Linux alta 2');
    await agregar('Prueba Linux alta 3');
    expect(find.text('Prueba Linux alta 1'), findsOneWidget);
    expect(find.text('Prueba Linux alta 2'), findsOneWidget);
    expect(find.text('Prueba Linux alta 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();

    var dbActual = AppDatabase.archivo();
    await tester.pumpWidget(GestorTareasApp(database: dbActual));
    await tester.pumpAndSettle();
    await esperarHasta(
      () => find.text('Prueba Linux alta 3').evaluate().isNotEmpty,
    );
    expect(find.text('Prueba Linux alta 1'), findsOneWidget);
    expect(find.text('Prueba Linux alta 2'), findsOneWidget);
    expect(find.text('Prueba Linux alta 3'), findsOneWidget);

    // P5: título vacío.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Agregar tarea'));
    await esperarHasta(
      () => find.text('Escribe un título para la tarea.').evaluate().isNotEmpty,
    );
    expect(find.text('Escribe un título para la tarea.'), findsOneWidget);

    // P2: completar la primera.
    await tester.tap(find.byType(Checkbox).first);
    await esperarHasta(() => find.text('Completada').evaluate().isNotEmpty);
    expect(find.text('Completada'), findsOneWidget);

    // P3: editar el título de la segunda.
    await tester.tap(find.byIcon(Icons.edit).at(1));
    await esperarHasta(
      () => find.text('Editar título').evaluate().isNotEmpty,
    );
    await tester.enterText(
      find.byType(TextFormField),
      'Prueba Linux editada',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await esperarHasta(
      () => find.text('Prueba Linux editada').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.text('Prueba Linux editada'), findsOneWidget);

    // P4: eliminar la tercera.
    await tester.tap(find.byIcon(Icons.delete_outline).at(2));
    await esperarHasta(
      () => find.text('Eliminar tarea').evaluate().isNotEmpty,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await esperarHasta(
      () => find.text('Prueba Linux alta 3').evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.text('Prueba Linux alta 3'), findsNothing);

    var tareas = await dbActual.obtenerTareas();
    expect(
      tareas.map((tarea) => tarea.titulo),
      ['Prueba Linux alta 1', 'Prueba Linux editada'],
    );
    expect(tareas.first.completada, isTrue);
    expect(tareas.last.completada, isFalse);

    // Simula cerrar la app: se desmonta la interfaz y se cierra la base.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await dbActual.close();

    // Reabre el mismo archivo persistente y vuelve a montar la app.
    final dbReabierta = AppDatabase.archivo();
    await tester.pumpWidget(GestorTareasApp(database: dbReabierta));
    await tester.pumpAndSettle();
    await esperarHasta(
      () => find.text('Prueba Linux editada').evaluate().isNotEmpty,
    );

    expect(find.text('Prueba Linux alta 1'), findsOneWidget);
    expect(find.text('Prueba Linux editada'), findsOneWidget);
    expect(find.text('Prueba Linux alta 3'), findsNothing);
    expect(find.text('Completada'), findsOneWidget);

    tareas = await dbReabierta.obtenerTareas();
    expect(
      tareas.map((tarea) => tarea.titulo),
      ['Prueba Linux alta 1', 'Prueba Linux editada'],
    );
    expect(tareas.first.completada, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await dbReabierta.close();
  });
}
