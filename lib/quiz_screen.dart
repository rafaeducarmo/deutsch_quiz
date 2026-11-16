// Pantalla principal del quiz.
// Aquí solo hay interfaz y estado; las reglas de comparación viven en
// quiz_logic.dart.

import 'package:material_ui/material_ui.dart';

import 'quiz_logic.dart';
import 'words.dart';

/// StatefulWidget: una pantalla que CAMBIA mientras juegas (palabras
/// acertadas, mensajes...). Flutter separa el widget (inmutable) de su
/// estado (la clase _QuizScreenState), que es donde guardamos lo que cambia.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Controlador: nos deja leer y borrar el texto del campo desde el código.
  final TextEditingController _controller = TextEditingController();

  // FocusNode: representa el "foco" del teclado. Con él podemos pedir que
  // el cursor vuelva al campo después de acertar. Se crea UNA vez aquí y se
  // libera en dispose(); si se creara dentro de build() se perdería el foco
  // en cada actualización de la pantalla (típico bug de "no puedo escribir").
  final FocusNode _focus = FocusNode();

  // ---- TODO EL ESTADO DEL JUEGO está en estas 5 variables. ----
  // _reiniciar() las restaura todas; por eso reiniciar funciona siempre.

  /// Modo de juego actual.
  QuizMode _modo = QuizMode.deToEn;

  /// Palabras acertadas: índice en `words` -> texto que se muestra en la celda.
  final Map<int, String> _acertadas = {};

  /// true después de presionar "Me rindo".
  bool _rendido = false;

  /// Mensaje bajo el campo y si es un aviso de error (para pintarlo distinto).
  String _mensaje = '';
  bool _mensajeEsError = false;

  /// ¿Completó las 200? Se calcula a partir de las acertadas, no se guarda
  /// aparte, así nunca se puede desincronizar.
  bool get _ganado => _acertadas.length == words.length;

  /// El campo solo se puede usar mientras el juego sigue en marcha.
  bool get _campoActivo => !_rendido && !_ganado;

  @override
  void dispose() {
    // Siempre liberar los objetos que lo necesitan.
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Devuelve el foco al campo. Se hace "después del frame" porque justo
  /// después de setState() la pantalla aún se está reconstruyendo: si el
  /// campo estaba desactivado (tras rendirse), todavía no se ha reactivado
  /// y pedir el foco en ese momento no tendría efecto.
  void _devolverFoco() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Marca una palabra como acertada y prepara el campo para la siguiente.
  void _marcar(MatchResult r) {
    setState(() {
      _acertadas[r.index] = r.answer;
      _mensaje = _ganado
          ? '🎉 ¡Felicidades! Completaste las ${words.length} palabras'
          : '✔ ${promptFor(words[r.index], _modo)} = ${r.answer}';
      _mensajeEsError = false;
    });
    _controller.clear(); // vaciar el campo (no dispara onChanged)
    _devolverFoco(); // y que el cursor siga ahí
  }

  /// Se llama en cada tecla. Marca sola la palabra si coincide sin ambigüedad.
  void _alCambiar(String texto) {
    final r = findMatch(texto, words, _acertadas.keys.toSet(), _modo);
    if (r != null) {
      _marcar(r);
    } else if (_mensajeEsError) {
      // Al seguir escribiendo, desaparece el aviso de "no coincide".
      setState(() {
        _mensaje = '';
        _mensajeEsError = false;
      });
    }
  }

  /// Se llama al presionar Enter: aquí sí se aceptan los casos ambiguos.
  void _alEnviar(String texto) {
    if (texto.trim().isEmpty) {
      _devolverFoco();
      return;
    }
    final r = findMatch(texto, words, _acertadas.keys.toSet(), _modo,
        enviado: true);
    if (r != null) {
      _marcar(r);
    } else {
      // No se vacía el campo: así el jugador puede corregir lo que escribió.
      setState(() {
        _mensaje = 'No coincide con ninguna palabra pendiente';
        _mensajeEsError = true;
      });
      _devolverFoco();
    }
  }

  /// "Me rindo": desactiva el campo y deja ver las respuestas que faltan.
  /// No borra nada: las acertadas se quedan como están.
  void _rendirse() {
    if (_rendido || _ganado) return;
    final faltan = words.length - _acertadas.length;
    setState(() {
      _rendido = true;
      _mensaje = 'Te rendiste: faltaron $faltan palabras';
      _mensajeEsError = false;
    });
  }

  /// "Reiniciar": vuelve TODO al estado inicial. No lee ningún estado
  /// anterior para decidir qué hacer, así que funciona igual antes de
  /// jugar, a mitad de partida, después de rendirse o después de ganar.
  void _reiniciar() {
    setState(() {
      _acertadas.clear();
      _rendido = false;
      _mensaje = '';
      _mensajeEsError = false;
    });
    _controller.clear();
    _devolverFoco(); // el campo ya estará activo cuando se pida el foco
  }

  /// Cambiar de modo = poner el modo nuevo y reiniciar.
  void _cambiarModo(QuizMode nuevo) {
    if (nuevo == _modo) return;
    setState(() => _modo = nuevo);
    _reiniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _barraSuperior(context), // fija: está fuera del scroll
          Expanded(child: _cuadricula()), // ocupa el resto y hace scroll
        ],
      ),
    );
  }

  Widget _barraSuperior(BuildContext context) {
    final total = words.length;
    final aciertos = _acertadas.length;
    final porcentaje = (aciertos * 100 / total).toStringAsFixed(0);
    final tema = Theme.of(context);

    final campo = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: _campoActivo, // se desactiva al rendirse o al ganar
      autofocus: true, // el cursor ya está en el campo al abrir
      autocorrect: false,
      enableSuggestions: false,
      onChanged: _alCambiar,
      onSubmitted: _alEnviar,
      // Si onEditingComplete es null, Flutter QUITA el foco al presionar
      // Enter. Con una función vacía no lo quita.
      onEditingComplete: () {},
      // Hacer clic fuera del campo (p. ej. en la cuadrícula) no debe
      // quitarle el foco.
      onTapOutside: (_) {},
      decoration: InputDecoration(
        hintText: _modo == QuizMode.deToEn
            ? 'Escribe la traducción en inglés…'
            : 'Escribe la palabra en alemán…',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    // Selector de modo + botones.
    final controles = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<QuizMode>(
          // softWrap: false + maxLines: 1 -> el texto nunca se parte en dos
          // líneas; el botón se ensancha lo necesario.
          segments: const [
            ButtonSegment(
              value: QuizMode.deToEn,
              label: Text('DE → EN', softWrap: false, maxLines: 1),
            ),
            ButtonSegment(
              value: QuizMode.enToDe,
              label: Text('EN → DE', softWrap: false, maxLines: 1),
            ),
          ],
          selected: {_modo},
          showSelectedIcon: false,
          onSelectionChanged: (seleccion) => _cambiarModo(seleccion.first),
        ),
        FilledButton(
          onPressed: _campoActivo ? _rendirse : null, // null = desactivado
          child: const Text('Me rindo'),
        ),
        OutlinedButton(
          onPressed: _reiniciar, // SIEMPRE activo
          child: const Text('Reiniciar'),
        ),
      ],
    );

    return Material(
      elevation: 4,
      color: tema.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: título y contador.
              Row(
                children: [
                  Text('Deutsch Quiz', style: tema.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '$aciertos/$total  ($porcentaje%)',
                    style: tema.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: el único campo de texto y los controles. En pantallas
              // anchas van en la misma fila; en angostas, uno debajo del otro.
              LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth >= 800) {
                    return Row(
                      children: [
                        Expanded(child: campo),
                        const SizedBox(width: 12),
                        controles,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [campo, const SizedBox(height: 8), controles],
                  );
                },
              ),
              const SizedBox(height: 6),
              // Fila 3: mensaje (último acierto, aviso o victoria). Altura
              // fija para que la barra no "salte" al aparecer o desaparecer.
              SizedBox(
                height: 20,
                child: Text(
                  _mensaje,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mensajeEsError
                        ? Colors.red.shade700
                        : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuadricula() {
    // LayoutBuilder nos dice cuánto espacio hay, para elegir las columnas.
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho >= 1000 ? 4 : (ancho >= 600 ? 2 : 1);
        final filas = gridRows(words.length, columnas);

        // ListView.builder solo construye las filas visibles (rápido).
        // Cada fila es un Row con una celda por columna; el índice de la
        // palabra sale de gridIndex para ordenar POR COLUMNAS.
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filas,
          itemBuilder: (context, fila) {
            return Row(
              children: [
                for (var c = 0; c < columnas; c++)
                  Expanded(
                    child: _fila(gridIndex(
                      fila: fila,
                      columna: c,
                      columnas: columnas,
                      total: words.length,
                    )),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Un par de celdas: pregunta (oscura) | respuesta (amarilla, verde o roja).
  Widget _fila(int? indice) {
    if (indice == null) return const SizedBox(height: 40); // celda vacía
    final acertada = _acertadas.containsKey(indice);

    // Qué se escribe en la celda de respuesta y de qué color.
    final String textoRespuesta;
    final Color fondo;
    final Color colorTexto;
    if (acertada) {
      textoRespuesta = _acertadas[indice]!; // verde
      fondo = Colors.green.shade400;
      colorTexto = Colors.black;
    } else if (_rendido) {
      textoRespuesta = revealAnswer(words[indice], _modo); // roja
      fondo = Colors.yellow.shade300;
      colorTexto = Colors.red.shade800;
    } else {
      textoRespuesta = ''; // pendiente
      fondo = Colors.yellow.shade300;
      colorTexto = Colors.black;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: _celda(
                promptFor(words[indice], _modo),
                fondo: Colors.blueGrey.shade800,
                colorTexto: Colors.white,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _celda(
                textoRespuesta,
                fondo: fondo,
                colorTexto: colorTexto,
                negrita: !acertada && _rendido,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Una celda de color con texto (recortado con "…" si no cabe).
  Widget _celda(String contenido,
      {required Color fondo, required Color colorTexto, bool negrita = false}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        contenido,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorTexto,
          fontSize: 14,
          fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
