// Punto de entrada de la app: arranca Flutter y muestra la pantalla del quiz.

import 'package:material_ui/material_ui.dart';

import 'quiz_screen.dart';

void main() {
  runApp(const DeutschQuizApp());
}

class DeutschQuizApp extends StatelessWidget {
  const DeutschQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deutsch Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const QuizScreen(),
    );
  }
}
