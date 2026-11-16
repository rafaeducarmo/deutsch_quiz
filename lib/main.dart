// Punto de entrada de la app: arranca Flutter y muestra la pantalla del quiz.

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'quiz_screen.dart';

void main() {
  runApp(const DeutschQuizApp());
}

class DeutschQuizApp extends StatelessWidget {
  /// [random] solo lo usan los tests (para tener un orden conocido).
  const DeutschQuizApp({super.key, this.random});

  final Random? random;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deutsch Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: QuizScreen(random: random),
    );
  }
}
