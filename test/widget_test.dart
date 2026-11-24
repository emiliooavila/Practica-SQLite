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

  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pump();
  }

  /// Avanza animaciones (diálogos, SnackBars) sin usar `pumpAndSettle`.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Deja que un SnackBar termine para no dejar timers pendientes.
  Future<void> cerrarMensaje(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Desmonta la interfaz y deja que Drift cancele su stream antes de que
  /// termine la prueba; si no, queda un Timer pendiente de `fake_async`.
  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // `Timer.run` de Drift es un temporizador de duración cero: hay que
    // avanzar el reloj falso para que se ejecute antes del chequeo final.
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await abrirApp(tester);

    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);

    await desmontar(tester);
  });

  testWidgets('Agrega una tarea y aparece en la lista', (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), 'Comprar leche');
    await tester.tap(find.text('Agregar tarea'));
    await asentar(tester);

    expect(find.text('Comprar leche'), findsOneWidget);
    expect(await db.obtenerTareas(), hasLength(1));

    await desmontar(tester);
  });

  testWidgets('Rechaza un título vacío o con solo espacios', (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Agregar tarea'));
    await asentar(tester);

    expect(find.text('Escribe un título para la tarea.'), findsOneWidget);
    expect(await db.obtenerTareas(), isEmpty);

    await cerrarMensaje(tester);
    await desmontar(tester);
  });

  testWidgets('Edita el título de una tarea', (tester) async {
    await db.crearTarea('Original');
    await abrirApp(tester);

    expect(find.text('Original'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await asentar(tester);
    expect(find.text('Editar título'), findsOneWidget);

    final campoDialogo = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(campoDialogo, '  Título editado  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await asentar(tester);
    await asentar(tester);

    expect(find.text('Título editado'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    expect((await db.obtenerTareas()).single.titulo, 'Título editado');

    await cerrarMensaje(tester);
    await desmontar(tester);
  });

  testWidgets('Cambia una tarea entre pendiente y completada', (tester) async {
    await db.crearTarea('Revisar apuntes');
    await abrirApp(tester);

    expect(find.text('Pendiente'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await asentar(tester);

    expect(find.text('Completada'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect((await db.obtenerTareas()).single.completada, isTrue);

    await tester.tap(find.byType(Checkbox));
    await asentar(tester);

    expect(find.text('Pendiente'), findsOneWidget);
    expect((await db.obtenerTareas()).single.completada, isFalse);

    await desmontar(tester);
  });

  testWidgets('Elimina una tarea después de confirmar', (tester) async {
    await db.crearTarea('Tarea que se elimina');
    await abrirApp(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await asentar(tester);
    expect(find.text('Eliminar tarea'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await asentar(tester);
    await asentar(tester);

    expect(find.text('Tarea que se elimina'), findsNothing);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    expect(await db.obtenerTareas(), isEmpty);

    await cerrarMensaje(tester);
    await desmontar(tester);
  });
}
