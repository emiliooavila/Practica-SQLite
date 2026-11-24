import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'screens/tareas_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Una sola instancia de la base para toda la vida de la aplicación.
  runApp(GestorTareasApp(database: AppDatabase.archivo()));
}

/// Punto de entrada de la aplicación.
///
/// La base de datos se recibe desde fuera para poder sustituirla por una
/// base en memoria durante las pruebas.
class GestorTareasApp extends StatelessWidget {
  const GestorTareasApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(database: database),
    );
  }
}
