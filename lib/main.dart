import 'package:chatbot_ui/screens/health_check.dart';
import 'package:flutter/material.dart';
import 'package:chatbot_ui/screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma NameCraft',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/health-check',
      routes: {
        '/health-check': (context) => const HealthCheckScreen(),
        '/chat': (context) => const ChatScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
