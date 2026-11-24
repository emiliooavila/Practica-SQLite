import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';

void main() {
  test('crea tareas y las consulta en orden', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.obtenerTareas(), isEmpty);

    final primerId = await db.crearTarea('Primera tarea');
    final segundoId = await db.crearTarea('Segunda tarea');

    expect(primerId, isNot(segundoId));

    final tareas = await db.obtenerTareas();
    expect(tareas.map((tarea) => tarea.titulo), ['Primera tarea', 'Segunda tarea']);
    expect(tareas.every((tarea) => !tarea.completada), isTrue);
  });

  test('los datos sobreviven al cerrar y reabrir la base', () async {
    final directorio =
        await Directory.systemTemp.createTemp('gestor_tareas_prueba');
    addTearDown(() async {
      if (await directorio.exists()) {
        await directorio.delete(recursive: true);
      }
    });

    final archivo = File('${directorio.path}/gestor_tareas_prueba.sqlite');

    final primeraApertura = AppDatabase(NativeDatabase(archivo));
    await primeraApertura.crearTarea('Sobrevive al reinicio');
    await primeraApertura.close();

    final segundaApertura = AppDatabase(NativeDatabase(archivo));
    addTearDown(segundaApertura.close);

    final tareas = await segundaApertura.obtenerTareas();
    expect(tareas, hasLength(1));
    expect(tareas.single.titulo, 'Sobrevive al reinicio');
    expect(tareas.single.completada, isFalse);
  });
}
