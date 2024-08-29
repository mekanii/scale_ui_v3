library globals;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class PortProvider with ChangeNotifier {
  final List<SerialPort> _ports = [];

  List<SerialPort>? get ports => _ports; // Add this getter

  void updatePorts(List<SerialPort> newPorts) {

    if (port != null) {
      if (!newPorts.any((_port) => _port.name == port!.name)) {
        port = null;
        _ports.clear();
      } else {
        _ports.removeWhere((_port) => _port.name != port!.name);
        newPorts.removeWhere((_port) => _port.name == port!.name);
      }
    } else {
      _ports.clear();
    }
    _ports.addAll(newPorts);
    // _ports!.addAll(newPorts);
    notifyListeners();
  }
}

SerialPort? port;

int _baudRate = 19200;
SerialPortReader? reader;

bool isConnected = false;

bool isFocused = false;

void detectUsbHotPlug(BuildContext context) {
  Timer.periodic(const Duration(seconds: 2), (timer) {
    if (!isConnected && !isFocused) {
      List<SerialPort> temp = [];
      for (final address in SerialPort.availablePorts) {
        temp.add(SerialPort(address));
      }

      // if (Provider.of<PortProvider>(context, listen: false).ports != temp) {
        Provider.of<PortProvider>(context, listen: false).updatePorts(temp);
      // }
    }
  });
}

Future<Map<String, dynamic>> open() async {
  final portconfig = SerialPortConfig();
  portconfig.baudRate = _baudRate;
  
  if (!port!.openReadWrite()) {
    isConnected = false;
    return {'status': false, 'error': SerialPort.lastError};
  }

  port!.config = portconfig;

  isConnected = true;
  return {'status': true, 'error': null};
}

Future<bool> close() async {
  return port!.close();
}

Future<bool> sendRequest(Map<String, dynamic> request) async {
  try {
    String message = '${jsonEncode(request)}\n';
    print(message);
    if (isConnected) {
      port!.write(Uint8List.fromList(utf8.encode(message)));
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }

  return false;
}

Future<String> readResponse({int timeout = 500}) async {
  port!.drain();
  StringBuffer response = StringBuffer();
  
  while (port!.bytesAvailable <= 0) {
    await Future.delayed(const Duration(milliseconds: 10));
  };

  final data = port!.read(2048, timeout: timeout);
  
  response.write(String.fromCharCodes(data));
  print(response.toString());
  return response.toString();
}

Future<void> portFlush() async {
  port!.flush(SerialPortBuffer.both);
  Future.delayed(const Duration(seconds: 1));
}

void notification(BuildContext context, String message, bool status) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      backgroundColor: status ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
      duration: const Duration(milliseconds: 1500),
    ),
  );
}

Future<bool> notificationTrueFalse(BuildContext context, String response) async {
    final responseData = json.decode(response);

    final message = responseData['message'];
     
    if (responseData['status'] == 200) {
      notification(context, message, true);
      return true;
    } else {
      notification(context, message, false);
      return false;
    }


  }

String convertToCsv(List<Map<String, dynamic>> data) {
  if (data.isEmpty) return '';

  final StringBuffer csvBuffer = StringBuffer();

  // Add headers
  csvBuffer.writeln(data.first.keys.join(','));

  // Add data rows
  for (var row in data) {
    csvBuffer.writeln(row.values.map((value) => '"$value"').join(','));
  }

  return csvBuffer.toString();
}

class GetDirectory {
  Future<Directory> logs() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/logs');
  }

  Future<Directory> export() async {
    final directory = await getDownloadsDirectory();
    return Directory('${directory!.path}/../Downloads/Scale UI');
  }
}

class SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> OK(BuildContext context) async {
    try {
      await _audioPlayer.setSource(AssetSource('assets/OK.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing OK sound: $e'); // Log the error
      notification(context, 'Error playing sound: $e', false);
    }
  }

  Future<void> NG(BuildContext context) async {
    try {
      await _audioPlayer.setSource(AssetSource('assets/NG.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      print('Error playing NG sound: $e'); // Log the error
      notification(context, 'Error playing sound: $e', false);
    }
  }

  void stopSound() {
    _audioPlayer.stop(); // Stop playing the sound
  }
}