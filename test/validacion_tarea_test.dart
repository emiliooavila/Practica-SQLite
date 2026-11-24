import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/validacion_tarea.dart';

void main() {
  group('normalizarTitulo', () {
    test('quita espacios al inicio y al final', () {
      expect(normalizarTitulo('  Comprar leche  '), 'Comprar leche');
    });
  });

  group('validarTitulo', () {
    test('rechaza una cadena vacía', () {
      expect(validarTitulo(''), 'Escribe un título para la tarea.');
    });

    test('rechaza un título compuesto solo por espacios', () {
      expect(validarTitulo('    '), 'Escribe un título para la tarea.');
    });

    test('acepta un título con contenido', () {
      expect(validarTitulo('  Estudiar SQLite  '), isNull);
    });

    test('acepta exactamente el máximo de caracteres', () {
      expect(validarTitulo('a' * longitudMaximaTitulo), isNull);
    });

    test('rechaza un título más largo que el máximo', () {
      expect(
        validarTitulo('a' * (longitudMaximaTitulo + 1)),
        'El título no puede superar los $longitudMaximaTitulo caracteres.',
      );
    });
  });
}
