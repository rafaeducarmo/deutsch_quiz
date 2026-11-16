import 'package:flutter_test/flutter_test.dart';

import 'package:deutsch_quiz/quiz_logic.dart';
import 'package:deutsch_quiz/words.dart';

/// Índice de una palabra alemana en la lista (para no depender de posiciones).
int indiceDe(String aleman) => words.indexWhere((w) => w.german == aleman);

void main() {
  group('normalizeEnglish', () {
    test('ignora mayúsculas, espacios extra y puntuación', () {
      expect(normalizeEnglish('  Dog!  '), 'dog');
      expect(normalizeEnglish('thank,   you.'), 'thank you');
    });

    test('quita "to ", "a ", "an ", "the " al inicio', () {
      expect(normalizeEnglish('to go'), 'go');
      expect(normalizeEnglish('The dog'), 'dog');
      expect(normalizeEnglish('a house'), 'house');
      expect(normalizeEnglish('an apple'), 'apple');
    });

    test('no quita "to"/"a" cuando no hay nada más', () {
      expect(normalizeEnglish('to'), 'to');
      expect(normalizeEnglish('a'), 'a');
    });

    test('no quita "to" en medio de la frase', () {
      expect(normalizeEnglish('ought to'), 'ought to');
      expect(normalizeEnglish('have to'), 'have to');
    });
  });

  group('normalizeGerman', () {
    test('el artículo es opcional', () {
      expect(normalizeGerman('der Hund'), 'hund');
      expect(normalizeGerman('Hund'), 'hund');
      expect(normalizeGerman('die Frau'), normalizeGerman('frau'));
      expect(normalizeGerman('das Kind'), 'kind');
    });

    test('ä = ae = a', () {
      expect(normalizeGerman('Mädchen'), normalizeGerman('Maedchen'));
      expect(normalizeGerman('Mädchen'), normalizeGerman('Madchen'));
    });

    test('ö = oe = o', () {
      expect(normalizeGerman('können'), normalizeGerman('koennen'));
      expect(normalizeGerman('können'), normalizeGerman('konnen'));
    });

    test('ü = ue = u', () {
      expect(normalizeGerman('die Tür'), normalizeGerman('tuer'));
      expect(normalizeGerman('früh'), normalizeGerman('fruh'));
    });

    test('ß = ss', () {
      expect(normalizeGerman('Straße'), normalizeGerman('strasse'));
      expect(normalizeGerman('groß'), normalizeGerman('GROSS'));
    });

    test('ignora puntuación y espacios extra', () {
      expect(normalizeGerman('  der   Hund!! '), 'hund');
    });
  });

  group('promptFor / revealAnswer', () {
    test('DE→EN muestra el alemán', () {
      expect(promptFor(words[indiceDe('der Hund')], QuizMode.deToEn), 'der Hund');
    });

    test('EN→DE muestra hasta 3 traducciones con " / "', () {
      final frau = words[indiceDe('die Frau')]; // woman, wife, mrs
      expect(promptFor(frau, QuizMode.enToDe), 'woman / wife / mrs');
      const muchas = Word('x', ['a1', 'b2', 'c3', 'd4'], 't');
      expect(promptFor(muchas, QuizMode.enToDe), 'a1 / b2 / c3');
    });

    test('revealAnswer da la respuesta principal', () {
      final hund = words[indiceDe('der Hund')];
      expect(revealAnswer(hund, QuizMode.deToEn), 'dog');
      expect(revealAnswer(hund, QuizMode.enToDe), 'der Hund');
    });
  });

  group('findMatch DE→EN', () {
    const modo = QuizMode.deToEn;

    test('encuentra una traducción válida', () {
      final r = findMatch('dog', words, {}, modo);
      expect(r, isNotNull);
      expect(r!.index, indiceDe('der Hund'));
      expect(r.answer, 'dog');
    });

    test('acepta cualquiera de las traducciones', () {
      final r = findMatch('home', words, {}, modo);
      expect(r!.index, indiceDe('das Haus'));
      expect(r.answer, 'home');
    });

    test('ignora mayúsculas, puntuación, "to" y "the"', () {
      expect(findMatch('  DOG! ', words, {}, modo)!.index, indiceDe('der Hund'));
      expect(findMatch('the dog', words, {}, modo)!.index, indiceDe('der Hund'));
      expect(findMatch('to run', words, {}, modo)!.index, indiceDe('laufen'));
    });

    test('devuelve null si no hay coincidencia o el texto está vacío', () {
      expect(findMatch('xyz', words, {}, modo), isNull);
      expect(findMatch('', words, {}, modo), isNull);
      expect(findMatch('   ', words, {}, modo), isNull);
    });

    test('no marca una palabra que ya está acertada', () {
      final hund = indiceDe('der Hund');
      expect(findMatch('dog', words, {hund}, modo), isNull);
    });

    test('"be" es ambiguo ("become"): solo con Enter', () {
      expect(findMatch('be', words, {}, modo), isNull);
      final r = findMatch('be', words, {}, modo, enviado: true);
      expect(r!.index, indiceDe('sein'));
    });

    test('"sea" es ambiguo ("search"): solo con Enter', () {
      expect(findMatch('sea', words, {}, modo), isNull);
      expect(findMatch('sea', words, {}, modo, enviado: true)!.index,
          indiceDe('das Meer'));
    });

    test('si la palabra más larga ya está acertada, ya no hay ambigüedad', () {
      // Damos por acertadas todas las palabras (menos "sein") cuya respuesta
      // empieza por "be": become, be able, beautiful, bed, beer, begin...
      final sein = indiceDe('sein');
      final acertadas = <int>{
        for (var i = 0; i < words.length; i++)
          if (i != sein && words[i].english.any((e) => e.startsWith('be'))) i,
      };
      expect(acertadas, contains(indiceDe('werden')));
      final r = findMatch('be', words, acertadas, modo);
      expect(r!.index, sein);
    });

    test('un prefijo de otra palabra no basta: "sear" no marca nada', () {
      expect(findMatch('sear', words, {}, modo, enviado: true), isNull);
    });

    test('las variantes de la misma palabra no cuentan como ambiguas', () {
      // 'holiday' es inicio de 'holidays', pero ambas son de der Urlaub.
      final r = findMatch('holiday', words, {}, modo);
      expect(r!.index, indiceDe('der Urlaub'));
    });
  });

  group('findMatch EN→DE', () {
    const modo = QuizMode.enToDe;

    test('acepta con y sin artículo', () {
      expect(findMatch('der Hund', words, {}, modo)!.index, indiceDe('der Hund'));
      expect(findMatch('hund', words, {}, modo)!.index, indiceDe('der Hund'));
    });

    test('acepta variantes de ä, ö, ü, ß', () {
      final madchen = indiceDe('das Mädchen');
      expect(findMatch('Maedchen', words, {}, modo)!.index, madchen);
      expect(findMatch('madchen', words, {}, modo)!.index, madchen);
      expect(findMatch('Mädchen', words, {}, modo)!.index, madchen);
      expect(findMatch('strasse', words, {}, modo)!.index, indiceDe('die Straße'));
      expect(findMatch('GROSS', words, {}, modo)!.index, indiceDe('groß'));
      expect(findMatch('tuer', words, {}, modo)!.index, indiceDe('die Tür'));
    });

    test('"der Morgen" y "morgen": marca la primera y luego la segunda', () {
      final manana = indiceDe('der Morgen');
      final manana2 = indiceDe('morgen');
      expect(manana, lessThan(manana2));

      final acertadas = <int>{};
      final r1 = findMatch('morgen', words, acertadas, modo);
      expect(r1!.index, manana);
      acertadas.add(r1.index);

      final r2 = findMatch('morgen', words, acertadas, modo);
      expect(r2!.index, manana2);
      acertadas.add(r2.index);

      expect(findMatch('morgen', words, acertadas, modo), isNull);
    });

    test('"essen" (sustantivo y verbo) funciona igual', () {
      final acertadas = <int>{};
      final r1 = findMatch('essen', words, acertadas, modo)!;
      expect(r1.index, indiceDe('das Essen'));
      acertadas.add(r1.index);
      expect(findMatch('essen', words, acertadas, modo)!.index, indiceDe('essen'));
    });

    test('un texto que es inicio de otra palabra espera a Enter', () {
      // "wo" es una palabra, pero también el inicio de "wohnen", "wollen"...
      expect(findMatch('wo', words, {}, modo), isNull);
      expect(findMatch('wo', words, {}, modo, enviado: true)!.index,
          indiceDe('wo'));
    });
  });

  group('gridIndex (orden por columnas)', () {
    int? celda(int fila, int col, int columnas) =>
        gridIndex(fila: fila, columna: col, columnas: columnas, total: 200);

    test('4 columnas: 1–50, 51–100, 101–150, 151–200', () {
      expect(gridRows(200, 4), 50);
      expect(celda(0, 0, 4), 0);
      expect(celda(1, 0, 4), 1); // la 2.ª palabra va debajo de la 1.ª
      expect(celda(49, 0, 4), 49);
      expect(celda(0, 1, 4), 50);
      expect(celda(0, 2, 4), 100);
      expect(celda(49, 3, 4), 199);
    });

    test('2 columnas: 1–100 y 101–200', () {
      expect(celda(0, 0, 2), 0);
      expect(celda(99, 0, 2), 99);
      expect(celda(0, 1, 2), 100);
      expect(celda(99, 1, 2), 199);
    });

    test('1 columna: en orden', () {
      expect(celda(0, 0, 1), 0);
      expect(celda(199, 0, 1), 199);
    });

    test('con un total que no divide exacto quedan celdas vacías', () {
      // 10 palabras en 4 columnas: 3 filas -> columnas de 3, 3, 3, 1.
      int? c(int f, int col) =>
          gridIndex(fila: f, columna: col, columnas: 4, total: 10);
      expect(gridRows(10, 4), 3);
      expect(c(0, 3), 9);
      expect(c(1, 3), isNull);
      expect(c(2, 3), isNull);
    });

    test('cada palabra aparece exactamente una vez', () {
      for (final columnas in [1, 2, 4]) {
        final vistas = <int>{};
        for (var f = 0; f < gridRows(200, columnas); f++) {
          for (var c = 0; c < columnas; c++) {
            final i = celda(f, c, columnas);
            if (i != null) expect(vistas.add(i), isTrue);
          }
        }
        expect(vistas.length, 200);
      }
    });
  });

  group('integridad de los datos', () {
    test('hay 200 palabras', () {
      expect(words.length, 200);
    });

    for (final modo in QuizMode.values) {
      test('toda palabra se puede acertar escribiendo su respuesta ($modo)', () {
        for (var i = 0; i < words.length; i++) {
          for (final cruda in rawAnswers(words[i], modo)) {
            expect(normalize(cruda, modo), isNotEmpty,
                reason: '"$cruda" se normaliza a vacío');
            final r = findMatch(cruda, words, {}, modo, enviado: true);
            expect(r, isNotNull, reason: '"$cruda" no coincide con nada');
            // Puede coincidir con una palabra anterior que acepta lo mismo.
            expect(r!.index, lessThanOrEqualTo(i), reason: '"$cruda"');
          }
        }
      });
    }
  });
}
