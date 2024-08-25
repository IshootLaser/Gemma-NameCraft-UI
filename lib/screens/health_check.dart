import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key});

  @override
  HealthCheckScreenState createState() => HealthCheckScreenState();
}

class HealthCheckScreenState extends State<HealthCheckScreen> {
  bool infinityCheck = false;
  bool gemmaCheck = false;
  bool paligemmaCheck = false;
  bool databaseCheck = false;
  bool backendCheck = false;

  @override
  void initState() {
    super.initState();
    startHealthCheck();
  }


  @override
  Widget build(BuildContext context) {
    final tenPercentHeight = MediaQuery.of(context).size.height * 0.1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Check', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: FittedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckItem('Backend Check', backendCheck),
                  _buildCheckItem('Infinity Server Check', infinityCheck),
                  _buildCheckItem('Gemma API Check', gemmaCheck),
                  _buildCheckItem('Paligemma API Check', paligemmaCheck),
                  _buildCheckItem('Database Check', databaseCheck),
                ],
              ),
              SizedBox(height: tenPercentHeight),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/chat');
                },
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(300, 100), // Set the width to 200 and the height to 100
                ),
                child: const Text('Go to Chat Screen', style: TextStyle(fontSize: 28)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String title, bool isHealthy) {
    var icon = isHealthy ? const Icon(Icons.check, color: Colors.green) : const CircularProgressIndicator();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: icon,
          ),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 24),),
        ],
      ),
    );
  }

  Future<void> startHealthCheck() async {
    while (true) {
      if (infinityCheck && gemmaCheck && paligemmaCheck && databaseCheck) {
        break;
      }
      _checkHealth();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  void _checkHealth() {
    String healthEndPoint = const String.fromEnvironment('healthEndPoint', defaultValue: 'http://localhost:5418/health');
    http.get(Uri.parse(healthEndPoint)).then(
      (response) {
        if (response.statusCode != 200) {
          return;
        }
        // json parse body string as Map<String, dynamic>
        Map<String, dynamic> body = json.decode(response.body);
        setState(() {
          infinityCheck = body['infinity'] == true;
          gemmaCheck = body['gemma'] == true;
          paligemmaCheck = body['paligemma'] == true;
          databaseCheck = body['database'] == true;
          backendCheck = true;
        });
      },
    ).catchError((e) {
      print('Error: $e');
    });
  }
}