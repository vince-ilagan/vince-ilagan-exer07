import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

//taken from sample code
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
      theme: ThemeData(primarySwatch: Colors.indigo),
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
  //state variables
  bool isRecording = false;
  bool permissionGranted = false;
  Coordinates? location;

  //for motion intensity
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  List<double> _motionMagnitudes = [];
  DateTime? _lastSampleTime;

  //for recording audio
  final record = AudioRecorder();
  int recordCount = 0;

  //for playing audio
  final _audioPlayer = AudioPlayer();
  String? playingFilePath;

  @override
  void initState() {
    _checkPermissions();
    super.initState();
    _audioPlayer.onPlayerComplete.listen(
      (_) => setState(() => playingFilePath = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = Provider.of<LogProvider>(context).records;
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
                //checks if recording or not
                onPressed: isRecording ? _stopRecording : _startRecording,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      //displays text accordingly
                      isRecording ? "Stop Recording" : "Start Recording",
                      style: TextStyle(
                        fontSize: 16,
                        //changes color based if recording or not
                        color: isRecording ? Colors.red : Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isRecording ? Icons.stop : Icons.play_arrow,
                      color: isRecording ? Colors.red : Colors.indigo,
                    ),
                  ],
                ),
              ),
            ),
          ),
          //shows the complete list of recordings
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final record = logs[index];
                bool isHigh = record.averageMotion > 15.0;

                return Container(
                  color: isHigh ? Colors.red : Colors.transparent,
                  child: ListTile(
                    title: Text(record.fileName),
                    subtitle: Text(
                      "(${record.location.latitude.toStringAsFixed(5)}, ${record.location.longitude.toStringAsFixed(5)})\nMotion intensity: ${record.averageMotion.toStringAsFixed(5)}",
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        playingFilePath == record.filePath
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                      onPressed: () async {
                        if (isRecording) return;
                        if (playingFilePath == record.filePath) {
                          await _audioPlayer.stop();
                          setState(() => playingFilePath = null);
                        } else {
                          await _audioPlayer.play(
                            DeviceFileSource(record.filePath),
                          );
                          setState(() => playingFilePath = record.filePath);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  //starts the sensor and calculates motion intensity every 250ms and is stored in list.
  void _startSensors() {
    _motionMagnitudes.clear();
    _lastSampleTime = null;

    _streamSubscriptions.add(
      userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        final now = DateTime.now();
        if (_lastSampleTime == null ||
            now.difference(_lastSampleTime!).inMilliseconds >= 250) {
          //solves magnitude intensity
          double magnitude = sqrt(
            pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2),
          );
          //list stored
          _motionMagnitudes.add(magnitude);
          _lastSampleTime = now;
        }
      }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  //modified permissions from sample codes
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

    //permisions for mic
    var micStatus = await Permission.microphone.request();

    setState(() {
      if (micStatus.isGranted &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse)) {
        permissionGranted = true;
      }
    });
  }

  //starts location tracking and also stored in list
  Future<void> _startLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      location = Coordinates(pos.latitude, pos.longitude);
    });

    _streamSubscriptions.add(
      Geolocator.getPositionStream().listen((Position position) {
        setState(() {
          location = Coordinates(position.latitude, position.longitude);
        });
      }),
    );
  }

  //combined start recording function that also starts audio recording, sensors, and location tracking
  Future<void> _startRecording() async {
    if (permissionGranted) {
      var dir = await getApplicationDocumentsDirectory();
      var filePath = '${dir.path}/recording${++recordCount}.m4a';
      _startSensors();
      await _startLocation();

      await record.start(RecordConfig(), path: filePath);
      setState(() => isRecording = true);
    }
  }

  //stops recording, sensor, and location tracking, also calculates average motion intensity and stores it to the list
  Future<void> _stopRecording() async {
    var path = await record.stop();
    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }
    _streamSubscriptions.clear();

    if (path != null && location != null) {
      double averageMotion = _motionMagnitudes.isNotEmpty
          ? _motionMagnitudes.reduce((a, b) => a + b) / _motionMagnitudes.length
          : 0.0;

      Provider.of<LogProvider>(context, listen: false).addRecord(
        AmbienceRecord(
          path.split('/').last,
          path,
          Coordinates(location!.latitude, location!.longitude),
          averageMotion,
        ),
      );
    }
    setState(() => isRecording = false);
  }
}
