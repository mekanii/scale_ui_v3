import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'globals.dart';

class ScaleView extends StatefulWidget {
  const ScaleView({super.key});

  @override
  ScaleViewState createState() => ScaleViewState();
}

class Part {
  int id;
  String name;
  double std;
  String unit;
  double hysteresis;

  Part({
    required this.id,
    required this.name,
    required this.std,
    required this.unit,
    required this.hysteresis
  });
}

class ScaleViewState extends State<ScaleView> {
  // bool _isReloadEnabled = false;

  GetWeight? _taskGetWeight;
  Map<String, dynamic>? _weightUpdate;

  int _partCount = 0;
  List<Part> _parts = [];
  Part? _selectedPart;
  Part? _lastPart;

  int _logCount = 0;
  double _weight = 0.00;
  int _lastCheck = 0;
  String _statusLabel = '';
  TextStyle? _textStyle;

  @override
  void initState() {
    super.initState();
    portFlush();
    _fetchParts();
    setState(() {
      _taskGetWeight = GetWeight(
        onWeightUpdate: (weightUpdate) {
          _onWeightUpdate(weightUpdate);
        }
      );
    });
  }

  @override
  void dispose() {
    _taskGetWeight?.stop();
    super.dispose();
  }

  void _onWeightUpdate(Map<String, dynamic> weightUpdate) async {
    try {
      if (mounted) {
        setState(() {
          _weightUpdate = weightUpdate;
          if (_selectedPart?.unit == 'gr' && weightUpdate['weight'] > -1 && weightUpdate['weight'] < 0) {
            _weight = 0;
          } else {
            _weight = weightUpdate['weight'];
          }
          
          if (weightUpdate['check'] == 1 && weightUpdate['check'] != _lastCheck) {
            _statusLabel = 'QTY GOOD';
            _textStyle = TextStyle(fontSize: 64, color: Colors.green[700]);
          } else if (weightUpdate['check'] == 2 && weightUpdate['check'] != _lastCheck) {
            _statusLabel = 'NOT GOOD';
            _textStyle = TextStyle(fontSize: 64, color: Colors.red[700]);
          } else if (weightUpdate['check'] == 0 && weightUpdate['check'] != _lastCheck) {
            _statusLabel = '';
          }
        });

        if (weightUpdate['check'] == 1 && weightUpdate['check'] != _lastCheck) {
          await SoundPlayer.OK(context);
          await logData(_selectedPart!, _weight, 'OK');
        } else if (weightUpdate['check'] == 2 && weightUpdate['check'] != _lastCheck) {
          await SoundPlayer.NG(context);
        }
        
        _lastCheck = weightUpdate['check'];
      }
    } catch (e) {
      notification(context, 'Error updating weight: $e', false);
    }
  }

  Future<bool> _fetchParts() async {
    bool status = false;

    setState(() {
      _parts = [];
      _partCount = 0;
    });

    try {
      final request = {
        'cmd': 1
      };

      List<dynamic> data = [];

      await sendRequest(request).then((value) async =>
        await readResponse().then((response) async => {
          if (mounted) await notificationTrueFalse(context, response).then((result) => {
            status = result,
            if (result) {
              data = json.decode(response)['data'],
              setState(() {
                _parts = data.map((part) => Part(
                  id: part['id'],
                  name: part['name'],
                  std: part['std'].toDouble(),
                  unit: part['unit'],
                  hysteresis: part['hysteresis'].toDouble(),
                )).toList();

                _partCount = _parts.length;
              })
            }
          })
        })
      );
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to load parts: $e', false);
      }
    }

    return status;
  }

  Future<void> _onScale() async {
    if (_lastPart != _selectedPart) {
      final request = {
        "cmd": 12,
      };
    
      await sendRequest(request).then((value) async =>
        await readResponse().then((response) async => {
          notificationTrueFalse(context, response),
          await Future.delayed(const Duration(milliseconds: 10))
        })
      );
    }

    _lastPart = _selectedPart;

    _taskGetWeight!.start(_selectedPart);
  }

  Future<void> _onTare() async {
    if (_selectedPart != null) {
      _taskGetWeight?.stop();
    }

    portFlush();

    final request = {
      "cmd": 7,
    };
  
    await sendRequest(request).then((value) async =>
      await readResponse().then((response) async => {
        notificationTrueFalse(context, response),
      })
    );

    if (_selectedPart != null) {
      _taskGetWeight!.start(_selectedPart);
    }

  }

  Future<void> logData(Part part, double weight, String status) async {
    // Get current date and time
    final DateTime now = DateTime.now();
    final String currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final String currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Create log entry
    final logEntry = {
      "date": currentDate,
      "time": currentTime,
      "part": part.name,
      "std": part.std,
      "unit": part.unit,
      "hysteresis": part.hysteresis,
      "measured": weight,
      "status": status
    };

    // Get the log file path
    final Directory logsDirectory = await GetDirectory().logs();
    final String logFilePath = '${logsDirectory.path}/log-$currentDate.json';

    // Check if the file exists
    File logFile = File(logFilePath);
    List<dynamic> logEntries = [];

    int count = 0;
    if (await logFile.exists()) {
      // If the file exists, read its contents
      String contents = await logFile.readAsString();
      if (contents.isNotEmpty) {
        logEntries = json.decode(contents);
        count = logEntries.where((e) => e['part'] == part.name).length;
      }
    }

    // Append the new log entry
    logEntries.add(logEntry);

    // Write the updated log entries back to the file
    await logFile.writeAsString(json.encode(logEntries), mode: FileMode.write).then((val) => {
      setState(() {
        _logCount = count + 1;
      })
    });
  }

  Future<int> getLogCount(Part part) async {
    // Get current date and time
    final DateTime now = DateTime.now();
    final String currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Get the log file path
    final Directory logsDirectory = await GetDirectory().logs();
    final String logFilePath = '${logsDirectory.path}/log-$currentDate.json';

    // Check if the file exists
    File logFile = File(logFilePath);
    List<dynamic> logEntries = [];

    int count = 0;
    if (await logFile.exists()) {
      // If the file exists, read its contents
      String contents = await logFile.readAsString();
      if (contents.isNotEmpty) {
        logEntries = json.decode(contents);
        count = logEntries.where((e) => e['part'] == part.name).length;
      }
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Scale',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(size: 32, Icons.sync),
                      title: const Text(
                        'Reload',
                        style: TextStyle(fontSize: 18),
                      ),
                      onTap: () => _fetchParts(),
                      tileColor: Colors.grey[200],
                      splashColor: Colors.black12,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                      child: Text('Found: $_partCount parts', style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<Part>(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      isExpanded: true,
                      value: _selectedPart,
                      hint: const Text('Select Part'),
                      icon: const Icon(Icons.arrow_downward_rounded),
                      iconSize: 24,
                      elevation: 16,
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                      focusColor: Colors.transparent,
                      underline: Container(
                        height: 1,
                        color: Colors.grey,
                      ),
                      onChanged: (Part? newValue) async {
                        if (_lastPart != null) _taskGetWeight!.stop();
                        final count = await getLogCount(newValue!);
                        setState(() {
                          _selectedPart = newValue;
                          _logCount = count;
                        });
                        await Future.delayed(const Duration(milliseconds: 1000));
                        await _onScale();
                      },
                      items: _parts.map<DropdownMenuItem<Part>>((Part part) {
                        return DropdownMenuItem<Part>(
                          value: part,
                          child: Text(part.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(size: 32, Icons.sync),
                      title: const Text(
                        'Tare',
                        style: TextStyle(fontSize: 18),
                      ),
                      onTap: () => _onTare(),
                      tileColor: Colors.grey[200],
                      splashColor: Colors.black12,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    const SizedBox(height: 142),
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                      child: Text(
                        _selectedPart == null ? '' : 'Count $_logCount',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                      child: Text(
                        _selectedPart == null ? '' : 'Standard ${ _selectedPart!.unit == 'gr' ? _selectedPart!.std.toStringAsFixed(0) : _selectedPart!.std.toStringAsFixed(2)} ${_selectedPart!.unit}',
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                      child: Text(
                        _selectedPart == null ? '' : 'Hysteresis ${_selectedPart!.hysteresis.toStringAsFixed(2)} ${_selectedPart!.unit}',
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                child: Text(
                  _selectedPart == null ? '' : _selectedPart!.unit == 'gr' ? '${_weight.toStringAsFixed(0)} ${_selectedPart!.unit}' : '${_weight.toStringAsFixed(2)} ${_selectedPart!.unit}',
                  style: const TextStyle(fontSize: 192),
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                child: Text(
                  _statusLabel,
                  style: _textStyle,
                ),
              ),
            ]
          )
        ]
      )
    );
  }
}

class GetWeight {
  final Function(Map<String, dynamic>) onWeightUpdate;
  bool isRunning = false;

  GetWeight({
    required this.onWeightUpdate,
  });


  void start(selectedPart) async {
    isRunning = true;

    final request = {
      "cmd": 8,
      "data": {
          "std": selectedPart.std,
          "unit": selectedPart.unit,
          "hysteresis": selectedPart.hysteresis
      }
    };
    while (isRunning) {
      try {
        await sendRequest(request).then((value) async =>
          await readResponse(timeout: 10).then((response) async => {
            if (json.decode(response)['status'] == 200) {
              onWeightUpdate(json.decode(response)['data'])
            }
          })
        );
      } catch (e) {
        print('errorrrrrrrrrrrrr $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void stop() {
    isRunning = false;
  }
}