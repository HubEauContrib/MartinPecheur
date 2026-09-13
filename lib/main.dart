import 'package:flutter/material.dart';

void main() {
  runApp(const MartinPecheurApp());
}

// Squelette minimal conforme au durcissement de l'analyse (S2). L'ecran
// carte le remplacera en M4.
class MartinPecheurApp extends StatelessWidget {
  const MartinPecheurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MartinPêcheur',
      home: Scaffold(body: Center(child: Text('MartinPêcheur'))),
    );
  }
}
