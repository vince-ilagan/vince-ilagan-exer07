import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class Coordinates {
  double latitude;
  double longitude;

  Coordinates(this.latitude, this.longitude);
}

//for the data for ambience record
class AmbienceRecord {
  String fileName;
  String filePath;
  Coordinates location;
  double averageMotion;

  AmbienceRecord(
    this.fileName,
    this.filePath,
    this.location,
    this.averageMotion,
  );
}

//used to store ambience records and for display in the UI
class LogProvider extends ChangeNotifier {
  List<AmbienceRecord> records = [];

  void addRecord(AmbienceRecord record) {
    records.insert(0, record);
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LogProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Ambience Logger'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isRecording = false; //placeholder
  bool permissionGranted = false;
  Coordinates? location;

  @override
  void initState() {
    _checkPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: OutlinedButton(
                onPressed: () {
                  setState(() => isRecording = !isRecording);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRecording ? "Stop Recording" : "Start Recording",
                      style: TextStyle(
                        fontSize: 16,
                        color: isRecording ? Colors.red : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isRecording ? Icons.stop : Icons.play_arrow,
                      color: isRecording ? Colors.red : Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission;
    bool serviceEnabled;

    // check location services
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    permissionGranted = true;
  }

  Future<void> getLocation() async {
    if (permissionGranted) {
      Position pos = await Geolocator.getCurrentPosition();
      var loc = Coordinates(pos.latitude, pos.longitude);

      setState(() {
        location = loc;
      });
    }
  }
}
