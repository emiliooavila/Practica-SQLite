import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Base aislada y en memoria: las pruebas no tocan los datos reales.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Desmonta la interfaz y deja que Drift cancele su stream antes de que
  /// termine la prueba; si no, queda un Timer pendiente de `fake_async`.
  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // `Timer.run` de Drift es un temporizador de duración cero: hay que
    // avanzar el reloj falso para que se ejecute antes del chequeo final.
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pump();

    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);

    await desmontar(tester);
  });

  testWidgets('Agrega una tarea y aparece en la lista', (tester) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Comprar leche');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Comprar leche'), findsOneWidget);
    expect(await db.obtenerTareas(), hasLength(1));

    await desmontar(tester);
  });
}
