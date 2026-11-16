// Tests de la pantalla del quiz (Fase 2).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:deutsch_quiz/main.dart';
import 'package:deutsch_quiz/words.dart';

/// Simula presionar Enter en el campo de texto.
Future<void> presionarEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// ¿Tiene el campo de texto el foco del teclado?
bool campoTieneFoco(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

void main() {
  // Pantalla ancha de escritorio (4 columnas).
  void pantallaAncha(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('empieza en 0/200 con el foco en el campo', (tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();

    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('escribir una respuesta la marca, vacía el campo y mantiene el foco',
      (tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();

    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text('✔ der Hund = dog'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(campoTieneFoco(tester), isTrue);

    // Se puede seguir escribiendo otra palabra.
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    expect(find.textContaining('2/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('un caso ambiguo ("be") solo se marca con Enter', (tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'be');
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);

    await presionarEnter(tester);
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('Enter sin coincidencia muestra el aviso y conserva el foco',
      (tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    expect(find.text('No coincide con ninguna palabra pendiente'), findsOneWidget);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);

    // Al seguir escribiendo, el aviso desaparece.
    await tester.enterText(find.byType(TextField), 'xyzw');
    await tester.pump();
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
  });

  // ------------------------- Fase 3 -------------------------

  bool campoActivo(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

  Future<void> abrir(WidgetTester tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();
  }

  testWidgets('"Me rindo" desactiva el campo y muestra en rojo las que faltan',
      (tester) async {
    await abrir(tester);
    // der Mann (primera palabra) queda pendiente; "das Kind" se acierta.
    await tester.enterText(find.byType(TextField), 'child');
    await tester.pump();

    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    expect(campoActivo(tester), isFalse);
    // La pendiente se ve en rojo...
    final pendiente = tester.widget<Text>(find.text('man'));
    expect(pendiente.style!.color, Colors.red.shade800);
    // ...y la acertada sigue verde con texto negro (no rojo).
    final acertada = tester.widget<Text>(find.text('child'));
    expect(acertada.style!.color, Colors.black);
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" funciona después de rendirse y se puede escribir',
      (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();
    expect(campoActivo(tester), isFalse);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump(); // deja correr el "foco después del frame"

    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text('man'), findsNothing); // ya no hay respuestas reveladas

    // Y se puede volver a jugar.
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
  });

  testWidgets('"Reiniciar" a mitad de partida limpia todo', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'xyz');
    await presionarEnter(tester);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.text('No coincide con ninguna palabra pendiente'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('completar las 200 muestra la felicitación y Reiniciar sigue sirviendo',
      (tester) async {
    await abrir(tester);
    for (final w in words) {
      await tester.enterText(find.byType(TextField), w.english.first);
      await presionarEnter(tester); // por si la palabra es ambigua
    }

    expect(find.textContaining('200/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsOneWidget);
    expect(campoActivo(tester), isFalse);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('0/200'), findsOneWidget);
    expect(find.textContaining('Felicidades'), findsNothing);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);
  });

  // ------------------------- Fase 4 -------------------------

  testWidgets('modo EN → DE: se ve el inglés y se escribe el alemán',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('modo_en_de')));
    await tester.pump();
    await tester.pump();

    expect(find.text('man'), findsOneWidget); // pregunta de "der Mann"
    expect(find.text('der Mann'), findsNothing);
    expect(campoTieneFoco(tester), isTrue);

    // Sin artículo y con la variante "ae" de ä: también vale.
    await tester.enterText(find.byType(TextField), 'mann');
    await tester.pump();
    expect(find.textContaining('1/200'), findsOneWidget);
    expect(find.text('der Mann'), findsOneWidget); // celda verde
    expect(find.text('✔ man = der Mann'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('el selector muestra hasta 3 traducciones separadas por " / "',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('modo_en_de')));
    await tester.pump();
    expect(find.text('woman / wife / mrs'), findsOneWidget);
  });

  testWidgets('cambiar de modo reinicia, incluso después de rendirse',
      (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('modo_en_de')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('0/200'), findsOneWidget);
    expect(campoActivo(tester), isTrue);
    expect(campoTieneFoco(tester), isTrue);

    // Y al volver a DE → EN también.
    await tester.tap(find.byKey(const Key('modo_de_en')));
    await tester.pump();
    await tester.pump();
    expect(find.text('der Mann'), findsOneWidget);
    expect(campoTieneFoco(tester), isTrue);
  });

  testWidgets('en EN → DE, "Me rindo" muestra el alemán en rojo', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('modo_en_de')));
    await tester.pump();
    await tester.tap(find.text('Me rindo'));
    await tester.pump();

    final t = tester.widget<Text>(find.text('der Mann'));
    expect(t.style!.color, Colors.red.shade800);
  });

  testWidgets('la cuadrícula se ordena por columnas (1–50 | 51–100 ...)',
      (tester) async {
    pantallaAncha(tester);
    await tester.pumpWidget(const DeutschQuizApp());
    await tester.pump();

    final p0 = tester.getTopLeft(find.text(words[0].german));
    final p1 = tester.getTopLeft(find.text(words[1].german));
    final p50 = tester.getTopLeft(find.text(words[50].german));

    // La palabra 2 está DEBAJO de la 1 (misma columna)...
    expect(p1.dx, p0.dx);
    expect(p1.dy, greaterThan(p0.dy));
    // ...y la 51 está en la fila de arriba, en la columna de la derecha.
    expect(p50.dy, p0.dy);
    expect(p50.dx, greaterThan(p0.dx));
  });
}
