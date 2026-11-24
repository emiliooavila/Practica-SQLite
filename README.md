# Gestor de tareas local con SQLite (multiplataforma)

Aplicación Flutter que administra tareas de forma **totalmente local**, sin servidor, sin
MySQL y sin conexión a internet. Una sola base de código para Android, iOS, Windows, Linux,
macOS y web.

> Práctica de *Programación de Dispositivos Móviles* — Ingeniería en Sistemas Computacionales,
> Universidad Autónoma de Aguascalientes.

## Estado del desarrollo

| Etapa | Alcance | Estado |
| --- | --- | --- |
| 1. Preparación y diseño | Dependencias, decisión de persistencia y esquema de la tabla | Completada |
| 2. Persistencia real | Apertura de la base, alta y consulta | Completada |
| 3. Operaciones restantes | Edición, cambio de estado, eliminación y validación | Pendiente |
| 4. Compatibilidad y pruebas | Web (wasm + worker), plataforma nativa y pruebas automatizadas | Pendiente |

## Tecnología de persistencia elegida

**SQLite mediante [Drift](https://drift.simonbinder.eu/) 2.35.4 y
[drift_flutter](https://pub.dev/packages/drift_flutter) 0.3.1.**

### ¿Por qué Drift y no otra opción?

- `sqflite` solo cubre Android/iOS/macOS: dejaría fuera web, Windows y Linux, que son
  requisito de la práctica.
- Usar `sqlite3` a mano obliga a escribir SQL, mapear filas y abrir la base de forma distinta
  en cada plataforma.
- **Drift** es una capa tipada sobre SQLite que funciona en las seis plataformas, genera el
  código de tablas y consultas con `build_runner`, ofrece *streams* reactivos (la lista se
  actualiza sola después de cada escritura) y permite inyectar una base en memoria para las
  pruebas.
- **drift_flutter** aporta `driftDatabase(...)`, que elige automáticamente el motor adecuado:
  SQLite nativo (FFI) en Android, iOS, Windows, Linux y macOS; SQLite compilado a WebAssembly
  en el navegador.

La información **no se sincroniza entre dispositivos**: cada instalación y cada origen web
tienen su propia base. Eso es intencional.

## Diseño de la tabla

Tabla `tareas`, definida como una tabla Dart de Drift (`lib/data/app_database.dart`):

| Columna | Tipo SQLite | Restricciones | Propósito |
| --- | --- | --- | --- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT NOT NULL` | Identificador único |
| `titulo` | `TEXT` | `NOT NULL`, no vacío (validado en la app) | Texto de la tarea |
| `completada` | `INTEGER` | `NOT NULL DEFAULT 0`, `CHECK (completada IN (0, 1))` | Estado pendiente/completada |

Equivalente SQL que genera Drift:

```sql
CREATE TABLE tareas (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  titulo TEXT NOT NULL,
  completada INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1))
);
```

### Identificación de registros

- El `id` es un `INTEGER PRIMARY KEY`, que en SQLite es un alias del `rowid` (entero de 64
  bits). `AUTOINCREMENT` garantiza que un id eliminado no se reutilice.
- El id **lo asigna SQLite**, nunca la interfaz: al insertar se omite y Drift devuelve el id
  generado. Editar, cambiar estado y eliminar usan `WHERE id = ?`.
- SQLite no tiene tipo booleano: `completada` se guarda como `0`/`1` y Drift lo expone como
  `bool`.

## Arquitectura prevista

```
lib/
├── main.dart                  # arranque, tema y creación de la base
├── data/
│   ├── app_database.dart      # tabla Tareas, apertura y operaciones CRUD
│   └── app_database.g.dart    # generado por build_runner (no se edita a mano)
└── screens/
    └── tareas_page.dart       # interfaz: alta, lista, edición, estado y eliminación
```

> El modelo `Tarea` que usa la interfaz es la clase que genera Drift a partir de la
> tabla, por lo que no se mantiene un segundo modelo escrito a mano.

Decisiones de diseño:

- **Una sola instancia** de `AppDatabase` por aplicación, creada fuera de `build()`.
- **Sin consultas dentro de `build()`**: la lista se obtiene con un `Stream` creado en
  `initState` y se muestra con `StreamBuilder`; Drift vuelve a emitir cuando cambia la tabla.
- **Escrituras asíncronas** (`await`) con manejo de errores y mensajes comprensibles.
- **Validación** con `trim()`: se rechazan títulos vacíos o compuestos solo por espacios.
- **Cierre de recursos**: el `TextEditingController` y la base se liberan en `dispose()`.

## Ubicación de la base de datos

`drift_flutter` guarda el archivo `gestor_tareas.sqlite` en la carpeta de documentos que
`path_provider` asigna a la aplicación:

- **Android:** almacenamiento privado de la app (`/data/data/<paquete>/app_flutter/`).
- **iOS y macOS:** carpeta `Documents` del *sandbox* de la app.
- **Windows:** carpeta Documentos del usuario.
- **Linux:** directorio XDG de documentos del usuario.
- **Web:** no hay archivo; Drift usa el sistema de archivos privado del origen (OPFS) o
  IndexedDB en el navegador.

Desinstalar la app (o borrar los datos del sitio en el navegador) elimina la base.

## Web: WebAssembly y worker

El navegador no incluye SQLite. Drift necesita dos archivos en `web/`, descargados de la
misma versión de Drift que usa `pubspec.lock`:

- `sqlite3.wasm`: SQLite compilado a WebAssembly.
- `drift_worker.dart.js`: worker que ejecuta la base fuera del hilo principal y coordina
  varias pestañas.

En esta práctica se obtienen del *release* `drift-2.35.4`
(<https://github.com/simolus3/drift/releases/tag/drift-2.35.4>). El asset del release se llama
`drift_worker.js`; en el proyecto se guarda como `drift_worker.dart.js`, que es el nombre que
se pasa a Drift (el nombre es libre, la versión es lo que importa). `flutter run` ya sirve el
`.wasm` con `Content-Type: application/wasm`. Sin cabeceras COOP/COEP, Drift utiliza
IndexedDB (más lento, pero persistente); con ellas usa OPFS.

## Cómo ejecutar

```bash
flutter pub get
dart run build_runner build    # regenera app_database.g.dart si cambia el esquema
flutter analyze
flutter test
flutter run -d chrome      # o linux, windows, macos, android, ios
```

Para habilitar OPFS en web (opcional):

```bash
flutter run -d chrome \
  --web-header=Cross-Origin-Opener-Policy=same-origin \
  --web-header=Cross-Origin-Embedder-Policy=require-corp
```

## Pruebas

- `test/widget_test.dart`: la interfaz abre sin errores y una tarea escrita se guarda y
  aparece en la lista (con base en memoria).
- `test/app_database_test.dart`: alta/consulta ordenada y, sobre todo, comprobación de que
  los datos sobreviven al **cerrar y reabrir** una base SQLite en archivo.
- Pruebas de validación de títulos (etapa 3/4).
- Pruebas de edición, cambio de estado y eliminación (etapa 4).
- Comprobaciones manuales P1–P6 sobre una plataforma nativa y web (etapa 4).

`app_database.g.dart` se versiona para que el repositorio se pueda clonar y ejecutar sin
regenerar el código; si se modifica el esquema, se regenera con `dart run build_runner build`.

## Referencias

- Drift: <https://drift.simonbinder.eu/>
- Drift en web: <https://drift.simonbinder.eu/platforms/web/>
- `drift_flutter`: <https://pub.dev/packages/drift_flutter>
- Persistencia con SQLite en Flutter: <https://docs.flutter.dev/cookbook/persistence/sqlite>
- Pruebas en Flutter: <https://docs.flutter.dev/testing/overview>
