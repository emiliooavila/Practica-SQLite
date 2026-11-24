import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// El archivo app_database.g.dart lo genera build_runner a partir de este.
part 'app_database.g.dart';

/// Tabla de tareas.
///
/// - `id`: entero autoincremental, alias del rowid de SQLite.
/// - `titulo`: texto obligatorio de 1 a 200 caracteres.
/// - `completada`: SQLite no tiene booleanos; Drift lo guarda como 0/1.
class Tareas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 200)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
}

/// Base de datos local de la aplicación.
///
/// Se usa una sola instancia por app. El constructor recibe un
/// [QueryExecutor] para poder inyectar una base en memoria en las pruebas.
@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Abre la base persistente que corresponde a la plataforma actual.
  ///
  /// En Android, iOS, Windows, Linux y macOS es un archivo SQLite dentro de
  /// la carpeta de documentos de la app. En web usa WebAssembly + el worker
  /// ubicados en `web/` (OPFS o IndexedDB según el navegador).
  AppDatabase.archivo()
      : super(
          driftDatabase(
            name: 'gestor_tareas',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.dart.js'),
            ),
          ),
        );

  @override
  int get schemaVersion => 1;

  /// Emite la lista completa cada vez que la tabla cambia.
  /// Es la fuente reactiva que consume la interfaz.
  Stream<List<Tarea>> observarTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  /// Consulta puntual, útil para pruebas y comprobaciones.
  Future<List<Tarea>> obtenerTareas() {
    return (select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// Inserta una tarea pendiente y devuelve el id asignado por SQLite.
  Future<int> crearTarea(String titulo) {
    return into(tareas).insert(TareasCompanion.insert(titulo: titulo));
  }
}
