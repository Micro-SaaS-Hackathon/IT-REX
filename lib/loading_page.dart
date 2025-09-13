import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  // A variable to hold the current progress value
  double _progressValue = 0.0;
  // Timer to update the progress bar
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // This starts the 5-second timer for navigation
    Timer(const Duration(seconds: 5), () {
      // After 5 seconds, navigate to the main screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'MedScan'), // Replace with your main page widget
        ),
      );
    });

    // This timer updates the progress bar every 100 milliseconds
    _timer = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      setState(() {
        _progressValue = _progressValue + (1.0 / 50.0);
        if (_progressValue > 1.0) {
          _progressValue = 1.0;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to prevent memory leaks
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Use Image.asset to display your icon.png
            Image.asset(
              'assets/images/icon.png', // Correct path to your image
              width: 150.0, // Set the width as needed
              height: 150.0, // Set the height as needed
            ),
            const SizedBox(height: 20.0),
            // Your App Name
            const Text(
              'MEDSCAN',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50.0),
            // Progress Bar with a linear loading animation
            LinearProgressIndicator(
              value: _progressValue,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              backgroundColor: Colors.blue.shade100,
            ),
            const SizedBox(height: 10.0),
            // Display the percentage
            Text('${(_progressValue * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

// NOTE: You'll need to create this widget yourself.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: const Center(child: Text('Welcome to the home page!')),
    );
  }
}