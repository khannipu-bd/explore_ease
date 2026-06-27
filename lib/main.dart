import 'package:explore_ease/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'presentation/screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExploreEase Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueAccent),
      home: const SplashScreen(),
    );
  }
}
