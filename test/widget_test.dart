// Tests de la pantalla del quiz.

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:deutsch_quiz/main.dart';
import 'package:deutsch_quiz/quiz_logic.dart';
import 'package:deutsch_quiz/words.dart';

/// Simula presionar Enter en el campo de texto.
Future<void> presionarEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// ¿Tiene el campo de texto el foco del teclado?
bool campoTieneFoco(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

bool campoActivo(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

String textoDelCampo(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Abre la app en una pantalla ancha de escritorio (4 columnas).
/// Por defecto la app arranca en modo ORDENADO; con [libre] cambia a LIBRE.
/// [azar] fija el generador aleatorio (con una semilla) para conocer el orden
/// que producirá "Mezclar orden".
Future<void> abrir(WidgetTester tester,
    {bool libre = false, Random? azar}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(DeutschQuizApp(random: azar));
  await tester.pump();
  if (libre) {
    await tester.tap(find.byKey(const Key('orden_libre')));
    await tester.pump();
    await tester.pump();
  }
}

/// Comprueba que la fila resaltada es la de la palabra cuya PREGUNTA es
/// [textoPregunta] (el rectángulo resaltado contiene a ese texto).
Future<void> expectSeleccion(WidgetTester tester, String textoPregunta) async {
  await tester.pumpAndSettle(); // deja terminar el scroll automático
  final sel = find.byKey(const Key('seleccion'));
  expect(sel, findsOneWidget, reason: 'debe haber una fila seleccionada');
  final texto = find.text(textoPregunta);
  expect(texto, findsOneWidget, reason: '"$textoPregunta" debe estar a la vista');
  expect(tester.getRect(sel).contains(tester.getCenter(texto)), isTrue,
      reason: 'la selección debería estar en "$textoPregunta"');
}

Future<void> tocar(WidgetTester tester, Key llave) async {
  await tester.tap(find.byKey(llave));
  await tester.pump();
  await tester.pump();
}

void main() {
  // =========================== MODO LIBRE ===========================
  // (el comportamiento de siempre: se acepta cualquier palabra pendiente)

  testWidgets('empieza en 0/200 con el foco en el campo', (tester) async {
    await abrir(tester);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: escribir una respuesta la marca, vacía el campo y mantiene el foco',
      (tester) async {
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();

    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text('✔ der Hund = dog'), findsOneWidget);
    expect(textoDelCampo(tester), '');
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    expect(find.textContaining('2/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: un caso ambiguo ("be") solo se marca con Enter',
      (tester) async {
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), 'be');
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);

    await presionarEnter(tester);
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('libre: Enter sin coincidencia muestra el aviso y conserva el foco',
      (tester) async {
    await abrir(tester, libre: true);

    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    expect(find.text('No coincide con ninguna palabra pendiente'), findsOneWidget);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'xyzw');
    await tester.pump();
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
  });

  testWidgets('libre: no hay resaltado ni botones Anterior/Siguiente',
      (tester) async {
    await abrir(tester, libre: true);
    expect(find.byKey(const Key('seleccion')), findsNothing);
    expect(find.byKey(const Key('btn_anterior')), findsNothing);
    expect(find.byKey(const Key('btn_siguiente')), findsNothing);
  });

  testWidgets('libre: Tab no saca el foco del campo', (tester) async {
    await abrir(tester, libre: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(campoTieneFoco(tester), isTrue);
  });

  // ---------------------- Me rindo / Reiniciar ----------------------

  testWidgets('"Me rindo" desactiva el campo y muestra en rojo las que faltan',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'child');
    await tester.pump();

    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    expect(campoActivo(tester), isFalse);
    final pendiente = tester.widget<Text>(find.text('man'));
    expect(pendiente.style!.color, Colors.red.shade800);
    final acertada = tester.widget<Text>(find.text('child'));
    expect(acertada.style!.color, Colors.black);
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" funciona después de rendirse y se puede escribir',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();
    expect(campoActivo(tester), isFalse);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();

    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text('man'), findsNothing);

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" a mitad de partida limpia todo', (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
    expect(textoDelCampo(tester), '');
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('completar las 200 (ordenado) muestra la felicitación y Reiniciar sigue sirviendo',
      (tester) async {
    await abrir(tester); // ordenado: se responde en orden, sin Enter
    for (final w in words) {
      await tester.enterText(find.byType(TextField), w.english.first);
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('200/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsOneWidget);
    expect(campoActivo(tester), isFalse);
    expect(find.byKey(const Key('seleccion')), findsNothing);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsNothing);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
    await expectSeleccion(tester, 'der Mann');
  });

  // ============================ MODOS EN/DE ============================

  testWidgets('modo EN → DE (libre): se ve el inglés y se escribe el alemán',
      (tester) async {
    await abrir(tester, libre: true);
    await tocar(tester, const Key('modo_en_de'));

    expect(find.text('man'), findsOneWidget);
    expect(find.text('der Mann'), findsNothing);
    expect(campoTieneFoco(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'mann');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text('der Mann'), findsOneWidget);
    expect(find.text('✔ man = der Mann'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('EN → DE muestra hasta 3 traducciones separadas por " / "',
      (tester) async {
    await abrir(tester, libre: true);
    await tocar(tester, const Key('modo_en_de'));
    expect(find.text('woman / wife / mrs'), findsOneWidget);
  });

  testWidgets('cambiar de modo reinicia, incluso después de rendirse',
      (tester) async {
    await abrir(tester, libre: true);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    await tocar(tester, const Key('modo_en_de'));
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);

    await tocar(tester, const Key('modo_de_en'));
    expect(find.text('der Mann'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('en EN → DE, "Me rindo" muestra el alemán en rojo', (tester) async {
    await abrir(tester, libre: true);
    await tocar(tester, const Key('modo_en_de'));
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    final t = tester.widget<Text>(find.text('der Mann'));
    expect(t.style!.color, Colors.red.shade800);
  });

  // =========================== MODO ORDENADO ===========================

  group('modo ordenado', () {
    testWidgets('arranca en Ordenado con la palabra 1 resaltada', (tester) async {
      await abrir(tester);
      await expectSeleccion(tester, 'der Mann');
      expect(find.byKey(const Key('btn_anterior')), findsOneWidget);
      expect(find.byKey(const Key('btn_siguiente')), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('solo acepta la respuesta de la palabra seleccionada',
        (tester) async {
      await abrir(tester);

      // "dog" es de otra palabra: no pasa nada.
      await tester.enterText(find.byType(TextField), 'dog');
      await tester.pump();
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, 'der Mann');

      // La respuesta de la seleccionada ("man") sí.
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(textoDelCampo(tester), '');
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('al acertar, la selección salta a la siguiente pendiente',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      await expectSeleccion(tester, 'die Frau');

      await tester.enterText(find.byType(TextField), 'woman');
      await tester.pump();
      await expectSeleccion(tester, 'das Kind');
    });

    testWidgets('las reglas de comparación son las mismas (EN → DE)',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('modo_en_de'));
      await expectSeleccion(tester, 'man');

      await tester.enterText(find.byType(TextField), 'MANN'); // sin artículo
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, 'woman / wife / mrs');
    });

    testWidgets('no hay ambigüedad: "be" marca sein sin Enter', (tester) async {
      await abrir(tester);
      // Selecciona "sein" (índice 3 de los verbos) haciendo clic en su celda.
      final indice = words.indexWhere((w) => w.german == 'sein');
      expect(indice, greaterThan(0));
      // Se navega hasta ahí con Siguiente (el orden es por índice).
      for (var i = 0; i < indice; i++) {
        await tester.tap(find.byKey(const Key('btn_siguiente')));
        await tester.pump();
      }
      await expectSeleccion(tester, 'sein');
      await tester.enterText(find.byType(TextField), 'be');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Enter con una respuesta equivocada muestra el aviso',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'dog');
      await presionarEnter(tester);

      expect(find.text('No coincide con la palabra seleccionada'), findsOneWidget);
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
      await expectSeleccion(tester, 'der Mann');
    });

    testWidgets('Siguiente y Anterior mueven la selección y vacían el campo',
        (tester) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'xx');
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, 'die Frau');
      expect(textoDelCampo(tester), '');
      expect(campoTieneFoco(tester), isTrue);

      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, 'der Mann');
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('navegar se salta las palabras ya acertadas', (tester) async {
      await abrir(tester);
      // Haz clic en "das Kind" (3.ª) y aciértala.
      await tester.tap(find.text('das Kind'));
      await tester.pump();
      await expectSeleccion(tester, 'das Kind');
      await tester.enterText(find.byType(TextField), 'child');
      await tester.pump();
      // Salta a la siguiente pendiente (4.ª).
      await expectSeleccion(tester, 'der Junge');

      // Anterior: la 3.ª está acertada, así que va a la 2.ª.
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, 'die Frau');
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, 'der Mann');
      // Siguiente, Siguiente: 2.ª y luego se salta la 3.ª -> 4.ª.
      await tocar(tester, const Key('btn_siguiente'));
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, 'der Junge');
    });

    testWidgets('es circular y la cuadrícula hace scroll hasta la seleccionada',
        (tester) async {
      await abrir(tester);

      // Anterior desde la primera -> la última (200.ª), que está muy abajo.
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, words.last.german); // "wann"

      // Siguiente desde la última -> la primera, y la lista vuelve arriba.
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, 'der Mann');
    });

    testWidgets('Tab = siguiente y Shift+Tab = anterior, sin perder el foco',
        (tester) async {
      await abrir(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, 'die Frau');
      expect(campoTieneFoco(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, 'das Kind');
      expect(campoTieneFoco(tester), isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await expectSeleccion(tester, 'die Frau');
      expect(campoTieneFoco(tester), isTrue);

      // Y se puede escribir enseguida.
      await tester.enterText(find.byType(TextField), 'woman');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Tab vacía el campo al cambiar de palabra', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'wo');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(textoDelCampo(tester), '');
    });

    testWidgets('clic en una celda pendiente la selecciona y devuelve el foco',
        (tester) async {
      await abrir(tester);
      await tester.tap(find.text('das Haus'));
      await tester.pump();
      await tester.pump();

      await expectSeleccion(tester, 'das Haus');
      expect(campoTieneFoco(tester), isTrue);
      expect(textoDelCampo(tester), '');
    });

    testWidgets('clic en una celda ya acertada no la selecciona', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      await expectSeleccion(tester, 'die Frau');

      await tester.tap(find.text('der Mann')); // ya acertada
      await tester.pump();
      await expectSeleccion(tester, 'die Frau'); // sigue donde estaba
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Me rindo quita el resaltado y desactiva la navegación',
        (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      expect(find.byKey(const Key('seleccion')), findsNothing);
      expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('btn_siguiente'))).onPressed,
          isNull);
      expect(
          tester.widget<OutlinedButton>(find.byKey(const Key('btn_anterior'))).onPressed,
          isNull);
    });

    testWidgets('Reiniciar vuelve a seleccionar la palabra 1', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      await tocar(tester, const Key('btn_siguiente'));
      await tocar(tester, const Key('btn_anterior')); // lejos de la 1.ª
      await tocar(tester, const Key('btn_anterior'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('0/200'), findsOneWidget);
      expect(campoActivo(tester), isTrue);
      expect(campoTieneFoco(tester), isTrue);
      expect(find.byKey(const Key('btn_siguiente')), findsOneWidget);
      await expectSeleccion(tester, 'der Mann');

      // Y se puede jugar de nuevo desde la primera.
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
    });

    testWidgets('Reiniciar sin haber jugado también deja todo en la palabra 1',
        (tester) async {
      await abrir(tester);
      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, 'die Frau');
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();
      await expectSeleccion(tester, 'der Mann');
    });

    testWidgets('cambiar entre Ordenado y Libre reinicia', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);

      await tocar(tester, const Key('orden_libre'));
      expect(find.textContaining('0/200'), findsOneWidget);
      expect(find.byKey(const Key('seleccion')), findsNothing);
      expect(find.byKey(const Key('btn_siguiente')), findsNothing);
      expect(campoTieneFoco(tester), isTrue);

      await tocar(tester, const Key('orden_ordenado'));
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, 'der Mann');
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('cambiar de modo de idioma reinicia y selecciona la palabra 1',
        (tester) async {
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      await tocar(tester, const Key('modo_en_de'));

      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, 'man');
    });
  });

  // ========================== MEZCLAR ORDEN ==========================

  group('mezclar orden', () {
    const semilla = 42;

    /// Los dos primeros órdenes que producirá un Random(semilla): el primero
    /// al activar el interruptor y el segundo al reiniciar.
    (List<int>, List<int>) ordenes() {
      final azar = Random(semilla);
      return (shuffledOrder(200, azar), shuffledOrder(200, azar));
    }

    /// Comprueba que las primeras palabras de la columna 1 son las de [orden],
    /// de arriba hacia abajo.
    void expectColumnaUno(WidgetTester tester, List<int> orden) {
      for (var p = 0; p < 6; p++) {
        final texto = find.text(words[orden[p]].german);
        expect(texto, findsOneWidget, reason: 'posición $p');
        if (p > 0) {
          final antes = tester.getTopLeft(find.text(words[orden[p - 1]].german));
          final ahora = tester.getTopLeft(texto);
          expect(ahora.dx, antes.dx, reason: 'misma columna');
          expect(ahora.dy, greaterThan(antes.dy), reason: 'debajo de la anterior');
        }
      }
    }

    testWidgets('la semilla de prueba da órdenes distintos entre sí y del original',
        (tester) async {
      final (o1, o2) = ordenes();
      expect(o1[0], isNot(0));
      expect(o2[0], isNot(0));
      expect(o1[0], isNot(o2[0]));
    });

    testWidgets('activar el interruptor reparte las palabras en orden aleatorio',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      expect(find.text('der Mann'), findsOneWidget); // orden original al inicio

      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, o1);
      expect(find.textContaining('0/200'), findsOneWidget);
      await expectSeleccion(tester, words[o1[0]].german);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Reiniciar genera un orden nuevo', (tester) async {
      final (o1, o2) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      expectColumnaUno(tester, o1);

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expectColumnaUno(tester, o2);
      await expectSeleccion(tester, words[o2[0]].german);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('Reiniciar después de rendirse también mezcla de nuevo',
        (tester) async {
      final (_, o2) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tester.tap(find.text('Me rindo'));
      await tester.pump();

      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();

      expectColumnaUno(tester, o2);
      expect(campoActivo(tester), isTrue);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('desactivar el interruptor vuelve al orden original',
        (tester) async {
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, [for (var i = 0; i < 200; i++) i]);
      await expectSeleccion(tester, 'der Mann');
    });

    testWidgets('ordenado: la selección y la navegación siguen el orden mezclado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      // La respuesta de la palabra ORIGINAL 1 no vale (ya no es la seleccionada).
      await tester.enterText(find.byType(TextField), words[0].english.first);
      await tester.pump();
      expect(find.textContaining('0/200'), findsOneWidget);

      // La de la seleccionada sí, y la selección pasa a la siguiente POSICIÓN.
      await tester.enterText(
          find.byType(TextField), words[o1[0]].english.first);
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(tester, words[o1[1]].german);

      await tocar(tester, const Key('btn_siguiente'));
      await expectSeleccion(tester, words[o1[2]].german);
      await tocar(tester, const Key('btn_anterior'));
      await expectSeleccion(tester, words[o1[1]].german);

      // Tab también sigue el orden mezclado.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await expectSeleccion(tester, words[o1[2]].german);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('ordenado: la navegación circular usa la última posición mezclada',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      await tocar(tester, const Key('btn_anterior')); // desde la posición 0
      await expectSeleccion(tester, words[o1[199]].german);
    });

    testWidgets('ordenado: se pueden completar las 200 en orden mezclado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      for (final i in o1) {
        await tester.enterText(find.byType(TextField), words[i].english.first);
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('200/200'), findsOneWidget);
      expect(find.textContaining('Felicidades'), findsOneWidget);
    });

    testWidgets('EN → DE ordenado con mezcla: se ve el inglés y se escribe el alemán',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('modo_en_de'));
      await tocar(tester, const Key('mezclar'));

      final primera = words[o1[0]];
      await expectSeleccion(tester, promptFor(primera, QuizMode.enToDe));

      await tester.enterText(find.byType(TextField), primera.german);
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      await expectSeleccion(
          tester, promptFor(words[o1[1]], QuizMode.enToDe));
    });

    testWidgets('libre con mezcla: cualquier palabra se acepta y no hay resaltado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));

      expectColumnaUno(tester, o1);
      expect(find.byKey(const Key('seleccion')), findsNothing);

      await tester.enterText(find.byType(TextField), 'dog');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('✔ der Hund = dog'), findsOneWidget);
      expect(campoTieneFoco(tester), isTrue);
    });

    testWidgets('libre con mezcla: Reiniciar da un orden nuevo y Me rindo funciona',
        (tester) async {
      final (_, o2) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      await tester.tap(find.text('Reiniciar'));
      await tester.pump();
      await tester.pump();
      expectColumnaUno(tester, o2);

      await tester.tap(find.text('Me rindo'));
      await tester.pump();
      expect(campoActivo(tester), isFalse);
      final primera = words[o2[0]];
      final roja = tester.widget<Text>(find.text(primera.english.first));
      expect(roja.style!.color, Colors.red.shade800);
    });

    testWidgets('EN → DE libre con mezcla: se acepta cualquier palabra', (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, libre: true, azar: Random(semilla));
      await tocar(tester, const Key('modo_en_de'));
      await tocar(tester, const Key('mezclar'));

      await tester.enterText(find.byType(TextField), 'hund');
      await tester.pump();
      expect(find.textContaining('1/200'), findsOneWidget);
      expect(find.text('✔ dog = der Hund'), findsOneWidget);
      expect(find.text(promptFor(words[o1[0]], QuizMode.enToDe)), findsOneWidget);
    });

    testWidgets('cambiar entre Ordenado y Libre conserva el interruptor activado',
        (tester) async {
      final (o1, _) = ordenes();
      await abrir(tester, azar: Random(semilla));
      await tocar(tester, const Key('mezclar'));
      expectColumnaUno(tester, o1);

      await tocar(tester, const Key('orden_libre'));
      // Sigue mezclado (con un orden nuevo, porque cambiar de modo reinicia).
      expect(tester.widget<FilterChip>(find.byKey(const Key('mezclar'))).selected,
          isTrue);
      expect(find.textContaining('0/200'), findsOneWidget);
    });
  });

  // ============================ CUADRÍCULA ============================

  testWidgets('la cuadrícula se ordena por columnas (1–50 | 51–100 ...)',
      (tester) async {
    await abrir(tester);

    final p0 = tester.getTopLeft(find.text(words[0].german));
    final p1 = tester.getTopLeft(find.text(words[1].german));
    final p50 = tester.getTopLeft(find.text(words[50].german));

    expect(p1.dx, p0.dx);
    expect(p1.dy, greaterThan(p0.dy));
    expect(p50.dy, p0.dy);
    expect(p50.dx, greaterThan(p0.dx));
  });
}
