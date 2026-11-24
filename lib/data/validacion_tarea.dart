/// Reglas de validación del título de una tarea.
///
/// Se mantienen fuera de la interfaz para poder probarlas por separado y
/// reutilizarlas al crear y al editar.
const int longitudMaximaTitulo = 200;

/// Quita espacios al inicio y al final.
String normalizarTitulo(String valor) => valor.trim();

/// Devuelve un mensaje de error, o `null` si el título es válido.
String? validarTitulo(String valor) {
  final titulo = normalizarTitulo(valor);

  if (titulo.isEmpty) {
    return 'Escribe un título para la tarea.';
  }
  if (titulo.length > longitudMaximaTitulo) {
    return 'El título no puede superar los $longitudMaximaTitulo caracteres.';
  }
  return null;
}
