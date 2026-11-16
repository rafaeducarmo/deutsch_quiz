// Lógica del quiz en Dart PURO: no importa Flutter.
// Así se puede probar con `flutter test` sin abrir ninguna pantalla,
// y la pantalla (quiz_screen.dart) solo se encarga de dibujar.

import 'words.dart';

/// Los dos modos de juego.
enum QuizMode {
  /// Veo el alemán, escribo el inglés.
  deToEn,

  /// Veo el inglés, escribo el alemán.
  enToDe,
}

/// Resultado de una coincidencia: qué palabra se acertó y con qué texto.
class MatchResult {
  /// Posición de la palabra en la lista `words`.
  final int index;

  /// La respuesta tal como está en los datos (sin normalizar),
  /// p. ej. "dog" o "der Hund". Sirve para mostrarla en la celda.
  final String answer;

  const MatchResult(this.index, this.answer);
}

// ---------------------------------------------------------------------------
// Normalización
// ---------------------------------------------------------------------------

/// Quita todo lo que no sea letra, número o espacio, y junta los espacios.
/// `unicode: true` hace que \p{L} (cualquier letra) funcione en Dart.
String _limpiar(String texto) {
  final sinPuntuacion = texto
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
  return sinPuntuacion.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Quita un prefijo de la lista solo si va seguido de un espacio.
/// Ej.: "to go" -> "go", pero "to" solo se queda como "to".
String _quitarPrefijo(String texto, List<String> prefijos) {
  for (final p in prefijos) {
    if (texto.startsWith('$p ')) return texto.substring(p.length + 1);
  }
  return texto;
}

/// Normaliza una respuesta en INGLÉS: minúsculas, sin puntuación,
/// sin "to " / "a " / "an " / "the " al inicio.
String normalizeEnglish(String texto) =>
    _quitarPrefijo(_limpiar(texto), const ['to', 'the', 'an', 'a']);

/// Normaliza una respuesta en ALEMÁN: minúsculas, sin puntuación,
/// artículo der/die/das opcional y ä=ae=a, ö=oe=o, ü=ue=u, ß=ss.
String normalizeGerman(String texto) {
  var t = _limpiar(texto)
      .replaceAll('ß', 'ss')
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u');
  // Después de quitar los acentos, "ae" "oe" "ue" también valen como a, o, u.
  t = t.replaceAll('ae', 'a').replaceAll('oe', 'o').replaceAll('ue', 'u');
  return _quitarPrefijo(t, const ['der', 'die', 'das']);
}

/// Normaliza según el idioma que hay que ESCRIBIR en cada modo.
String normalize(String texto, QuizMode modo) =>
    modo == QuizMode.deToEn ? normalizeEnglish(texto) : normalizeGerman(texto);

// ---------------------------------------------------------------------------
// Datos de cada palabra según el modo
// ---------------------------------------------------------------------------

/// Respuestas válidas de una palabra, SIN normalizar (tal como están en los datos).
List<String> rawAnswers(Word palabra, QuizMode modo) =>
    modo == QuizMode.deToEn ? palabra.english : [palabra.german];

/// Lo que se le muestra al jugador como pregunta.
/// DE→EN: el alemán. EN→DE: hasta 3 traducciones separadas por " / ".
String promptFor(Word palabra, QuizMode modo) => modo == QuizMode.deToEn
    ? palabra.german
    : palabra.english.take(3).join(' / ');

/// Respuesta que se muestra al rendirse (la principal de la palabra).
String revealAnswer(Word palabra, QuizMode modo) => rawAnswers(palabra, modo).first;

// ---------------------------------------------------------------------------
// Cuadrícula
// ---------------------------------------------------------------------------

/// Cuántas filas necesita la cuadrícula para [total] palabras en [columnas].
int gridRows(int total, int columnas) => (total + columnas - 1) ~/ columnas;

/// Índice de la palabra que va en la celda (fila, columna), ordenando POR
/// COLUMNAS como Sporcle: con 4 columnas y 200 palabras, la columna 0 lleva
/// las palabras 0–49, la 1 las 50–99, etc., de arriba hacia abajo.
/// Devuelve null si la celda queda vacía (última columna incompleta).
int? gridIndex({
  required int fila,
  required int columna,
  required int columnas,
  required int total,
}) {
  final indice = columna * gridRows(total, columnas) + fila;
  return indice < total ? indice : null;
}

// ---------------------------------------------------------------------------
// Coincidencias
// ---------------------------------------------------------------------------

/// Busca qué palabra PENDIENTE coincide con lo que escribió el jugador.
///
/// - [entrada]: el texto del campo.
/// - [lista]: todas las palabras (normalmente `words`).
/// - [acertadas]: índices que ya están resueltos (se ignoran).
/// - [enviado]: true si el jugador presionó Enter.
///
/// Reglas:
/// * Si dos pendientes aceptan lo mismo, gana la primera de la lista.
/// * Si la entrada coincide pero además es el INICIO de la respuesta de otra
///   palabra pendiente (ej. "be" y "become"), no se marca sola: solo cuando
///   [enviado] es true.
/// Devuelve null si no hay nada que marcar.
MatchResult? findMatch(
  String entrada,
  List<Word> lista,
  Set<int> acertadas,
  QuizMode modo, {
  bool enviado = false,
}) {
  final texto = normalize(entrada, modo);
  if (texto.isEmpty) return null;

  // 1) Primera palabra pendiente cuya respuesta coincide exactamente.
  int? indice;
  String? respuesta;
  for (var i = 0; i < lista.length && indice == null; i++) {
    if (acertadas.contains(i)) continue;
    for (final cruda in rawAnswers(lista[i], modo)) {
      if (normalize(cruda, modo) == texto) {
        indice = i;
        respuesta = cruda;
        break;
      }
    }
  }
  if (indice == null) return null;

  // 2) Si no se presionó Enter, comprobar que no sea inicio de otra respuesta
  //    más larga de OTRA palabra pendiente.
  if (!enviado) {
    for (var j = 0; j < lista.length; j++) {
      if (j == indice || acertadas.contains(j)) continue;
      for (final cruda in rawAnswers(lista[j], modo)) {
        final otra = normalize(cruda, modo);
        if (otra.length > texto.length && otra.startsWith(texto)) {
          return null; // ambiguo: esperar a Enter
        }
      }
    }
  }
  return MatchResult(indice, respuesta!);
}
