# Deutsch Quiz

App web en Flutter para aprender 200 palabras en alemán, al estilo de los
quizzes de Sporcle. Escribes las respuestas en un solo campo de texto y cada
palabra se marca sola al acertarla, sin temporizador.

- **Dos modos:** DE → EN (ves el alemán, escribes inglés) y EN → DE (al revés).
- **Botones:** "Me rindo" muestra en rojo lo que falta; "Reiniciar" empieza de cero.
- **Reglas:** se ignoran mayúsculas, puntuación y espacios extra; el artículo
  alemán es opcional y ä/ae/a, ö/oe/o, ü/ue/u, ß/ss valen igual. Si lo que
  escribes es el inicio de otra respuesta pendiente (p. ej. "be" y "become"),
  se marca al presionar Enter.

## Cómo correrla

```
cd C:\Users\rafae\proyectos\deutsch_quiz
flutter run -d chrome
```

## Tests

```
flutter analyze
flutter test
```

## Estructura

| Archivo                     | Qué hace                                        |
| --------------------------- | ----------------------------------------------- |
| `lib/words.dart`            | Datos: la clase `Word` y las 200 palabras       |
| `lib/quiz_logic.dart`       | Normalización y coincidencias (Dart puro)       |
| `lib/quiz_screen.dart`      | La pantalla del quiz                            |
| `lib/main.dart`             | Arranque de la app                              |
| `test/quiz_logic_test.dart` | Tests de las reglas de comparación y la cuadrícula |
| `test/widget_test.dart`     | Tests de la pantalla (foco, rendirse, reiniciar, modos) |
