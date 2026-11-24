import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/validacion_tarea.dart';

/// Pantalla principal: alta, consulta, edición, estado y eliminación.
///
/// La lista se obtiene de un [Stream] de la base, por lo que se actualiza
/// sola después de cada escritura. No se ejecutan consultas en `build()`.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();
  late final Stream<List<Tarea>> _tareasStream;

  @override
  void initState() {
    super.initState();
    _tareasStream = widget.database.observarTareas();
  }

  Future<void> _agregarTarea() async {
    final error = validarTitulo(_tituloController.text);
    if (error != null) {
      _mostrarMensaje(error);
      return;
    }

    try {
      await widget.database.crearTarea(normalizarTitulo(_tituloController.text));
      _tituloController.clear();
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo guardar la tarea. Inténtalo de nuevo.');
    }
  }

  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    try {
      final actualizadas =
          await widget.database.cambiarEstado(tarea.id, completada);
      if (!mounted) return;
      if (actualizadas == 0) {
        _mostrarMensaje('La tarea ya no existe.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo cambiar el estado de la tarea.');
    }
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (context) => _EditarTareaDialog(tituloInicial: tarea.titulo),
    );

    if (nuevoTitulo == null || !mounted) return;
    if (nuevoTitulo == tarea.titulo) return;

    try {
      final actualizadas =
          await widget.database.actualizarTitulo(tarea.id, nuevoTitulo);
      if (!mounted) return;
      if (actualizadas == 0) {
        _mostrarMensaje('La tarea ya no existe.');
      } else {
        _mostrarMensaje('Título actualizado.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo actualizar el título. Inténtalo de nuevo.');
    }
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Eliminar "${tarea.titulo}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      final eliminadas = await widget.database.eliminarTarea(tarea.id);
      if (!mounted) return;
      if (eliminadas == 0) {
        _mostrarMensaje('La tarea ya no existe.');
      } else {
        _mostrarMensaje('Tarea eliminada.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo eliminar la tarea. Inténtalo de nuevo.');
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _agregarTarea(),
              decoration: const InputDecoration(
                labelText: 'Nueva tarea',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Tarea>>(
                stream: _tareasStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'No se pudieron leer las tareas.\n'
                        'Revisa el almacenamiento de la aplicación.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tareas = snapshot.data!;
                  if (tareas.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay tareas guardadas'),
                    );
                  }

                  return ListView.builder(
                    itemCount: tareas.length,
                    itemBuilder: (context, index) {
                      final tarea = tareas[index];
                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: tarea.completada,
                            onChanged: (valor) {
                              if (valor != null) {
                                _alternarCompletada(tarea, valor);
                              }
                            },
                          ),
                          title: Text(
                            tarea.titulo,
                            style: tarea.completada
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          subtitle: Text(
                            tarea.completada ? 'Completada' : 'Pendiente',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editarTarea(tarea),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminarTarea(tarea),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para modificar el título de una tarea existente.
class _EditarTareaDialog extends StatefulWidget {
  const _EditarTareaDialog({required this.tituloInicial});

  final String tituloInicial;

  @override
  State<_EditarTareaDialog> createState() => _EditarTareaDialogState();
}

class _EditarTareaDialogState extends State<_EditarTareaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.tituloInicial);

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(normalizarTitulo(_controller.text));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar título'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: longitudMaximaTitulo,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _guardar(),
          validator: (valor) => validarTitulo(valor ?? ''),
          decoration: const InputDecoration(
            labelText: 'Título de la tarea',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
