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

  test('actualiza título y estado, y elimina por identificador', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.crearTarea('Original');

    expect(await db.actualizarTitulo(id, 'Título editado'), 1);
    expect(await db.cambiarEstado(id, true), 1);

    var tarea = (await db.obtenerTareas()).single;
    expect(tarea.titulo, 'Título editado');
    expect(tarea.completada, isTrue);

    expect(await db.eliminarTarea(id), 1);
    expect(await db.obtenerTareas(), isEmpty);

    // Operar con un id inexistente no debe afectar otras filas.
    expect(await db.actualizarTitulo(id, 'Otra vez'), 0);
    expect(await db.cambiarEstado(id, false), 0);
    expect(await db.eliminarTarea(id), 0);
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

  test('editar, cambiar estado y eliminar persisten al reabrir', () async {
    final directorio =
        await Directory.systemTemp.createTemp('gestor_tareas_crud');
    addTearDown(() async {
      if (await directorio.exists()) {
        await directorio.delete(recursive: true);
      }
    });

    final archivo = File('${directorio.path}/gestor_tareas_crud.sqlite');

    final primeraApertura = AppDatabase(NativeDatabase(archivo));
    final id = await primeraApertura.crearTarea('Título original');
    await primeraApertura.actualizarTitulo(id, 'Título editado');
    await primeraApertura.cambiarEstado(id, true);
    await primeraApertura.close();

    final segundaApertura = AppDatabase(NativeDatabase(archivo));
    var tarea = (await segundaApertura.obtenerTareas()).single;
    expect(tarea.titulo, 'Título editado');
    expect(tarea.completada, isTrue);

    expect(await segundaApertura.eliminarTarea(id), 1);
    await segundaApertura.close();

    final terceraApertura = AppDatabase(NativeDatabase(archivo));
    addTearDown(terceraApertura.close);
    expect(await terceraApertura.obtenerTareas(), isEmpty);
  });
}
