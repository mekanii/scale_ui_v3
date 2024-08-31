import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'globals.dart';

class SummaryView extends StatefulWidget {
  const SummaryView({super.key});

  @override
  SummaryViewState createState() => SummaryViewState();
}


class SummaryViewState extends State<SummaryView> {
  int _logCount = 0;
  List<String> _logs = [];
  String? _selectedLog;
  List<Map<String, dynamic>> _logData = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final logsDirectory = await GetDirectory().logs();
    final List<String> logs = [];

    try {
      if (await logsDirectory.exists()) {
        final List<FileSystemEntity> entities = await logsDirectory.list().toList();
        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.json')) {
            // Use Platform.pathSeparator for cross-platform compatibility
            logs.add(entity.path.split(Platform.pathSeparator).last);
          }
        }
        logs.sort((a, b) => b.compareTo(a));
      } else {
        notification(context, 'Logs directory does not exist. Creating now.', true);
        await logsDirectory.create(recursive: true);
      }
    } catch (e) {
      notification(context, 'Error reading logs directory: $e', false);
    }

    setState(() {
      _logs = logs;
      _logCount = logs.length;
    });
  }

  Future<void> _fetchLogData(String logFileName) async {
    final logsDirectory = await GetDirectory().logs();
    final logFile = File('${logsDirectory.path}/$logFileName');
    try {
      final contents = await logFile.readAsString();
      final List<dynamic> jsonData = json.decode(contents);

      // Process the data to group by part and count occurrences
      final Map<String, Map<String, dynamic>> groupedData = {};
      for (var item in jsonData) {
        final part = item['part'];
        if (groupedData.containsKey(part)) {
          if (item['status'] == 'OK') {
            groupedData[part]!['OK'] += 1;
          } else if (item['status'] == 'NG') {
            groupedData[part]!['NG'] += 1;
          }
        } else {
          groupedData[part] = {
            'part': part,
            'std': item['std'],
            'unit': item['unit'],
            'tolerance': item['tolerance'],
            'OK': item['status'] == 'OK' ? 1 : 0,
            'NG': item['status'] == 'NG' ? 1 : 0,
          };
        }
      }

      setState(() {
        _logData = groupedData.values.toList();
      });
    } catch (e) {
      notification(context, 'Error reading log file: $e', false);
    }
  }

  Future<void> _export(List<String> logFileNames) async {
    if (logFileNames.length > 0) {
      final directory = await getApplicationDocumentsDirectory();
      final logsDirectory = Directory('${directory.path}/logs');
      final List<Map<String, dynamic>> allLogData = [];

      // Fetch data from each log file
      for (String logFileName in logFileNames) {
        final logFile = File('${logsDirectory.path}/$logFileName');
        try {
          final contents = await logFile.readAsString();
          final List<dynamic> jsonData = json.decode(contents);
          jsonData.sort((a, b) {
            final dateA = a['date'];
            final dateB = b['date'];
            final timeA = a['time'];
            final timeB = b['time'];

            // Sort by date descending
            if (dateA.compareTo(dateB) > 0) return -1;
            if (dateA.compareTo(dateB) < 0) return 1;

            // If dates are the same, sort by time descending
            if (timeA.compareTo(timeB) > 0) return -1;
            if (timeA.compareTo(timeB) < 0) return 1;

            return 0;
          });
          allLogData.addAll(List<Map<String, dynamic>>.from(jsonData));
        } catch (e) {
          notification(context, 'Error reading log file $logFileName: $e', false);
        }
      }

      String csvData = convertToCsv(allLogData);

      final exportDirectory = await GetDirectory().export();
      final fileName = 'scale-ui-log-${DateFormat('yyyy-MM-dd-hhmmss').format(DateTime.now())}.csv';
      final csvFile = File('${exportDirectory.path}/$fileName');

      try {
        if (await exportDirectory.exists()) {
          await csvFile.writeAsString(csvData).then((file) => {
            notification(context, 'Exported to ${file.path}', true),
          });
        } else {
          await exportDirectory.create(recursive: true).then((dir) => {
            csvFile.writeAsString(csvData).then((file) => {
              notification(context, 'Exported to ${file.path}', true)
            })
          });
        }
      } catch (e) {
        notification(context, 'Error writing CSV file: $e', false);
      }
    } else {
      notification(context, 'Log is empty or not selected.', false);
    }
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
                // flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                      child: Text('Found: $_logCount logs', style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      isExpanded: true,
                      value: _selectedLog,
                      hint: const Text('Select Log'),
                      icon: const Icon(Icons.arrow_drop_down),
                      iconSize: 24,
                      elevation: 16,
                      style: const TextStyle(fontSize: 18, color: Colors.black),
                      focusColor: Colors.transparent,
                      underline: Container(
                        height: 1,
                        color: Colors.grey,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedLog = newValue!;
                        });
                        _fetchLogData(newValue!);
                      },
                      items: _logs.map<DropdownMenuItem<String>>((String log) {
                        return DropdownMenuItem<String>(
                          value: log,
                          child: Text(log.replaceAll('.json', '')),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(size: 32, Icons.arrow_circle_down),
                      title: const Text(
                        'Export',
                        style: TextStyle(fontSize: 18),
                      ),
                      onTap: () => _export(_selectedLog != null ? [_selectedLog!] : []),
                      // onTap: () => (),
                      tileColor: Colors.grey[200],
                      splashColor: Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(size: 32, Icons.downloading),
                      title: const Text(
                        'Export All',
                        style: TextStyle(fontSize: 18),
                      ),
                      onTap: () => _export(_logs),
                      // onTap: () => (),
                      tileColor: Colors.grey[200],
                      splashColor: Colors.black12,
                    ),
                    const SizedBox(height: 16),
                    // DataTable Before
                  ],
                ),
              ),
              Expanded(
                // flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container()
                  ],
                ),
              ),
            ],
          ),
          Flexible(
            child: _logData.isNotEmpty
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Part')),
                      DataColumn(label: Text('Standard')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Tolerance')),
                      DataColumn(label: Text('OK')),
                      DataColumn(label: Text('NG')),
                    ],
                    rows: _logData
                      .map((data) => DataRow(
                        cells: [
                          DataCell(Text(data['part'].toString())),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(data['std'].toString()), // Right aligned
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.center,
                              child: Text(data['unit'].toString()), // Right aligned
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(data['tolerance'].toString()), // Right aligned
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(data['OK'].toString()), // Right aligned
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(data['NG'].toString()), // Right aligned
                            ),
                          ),
                        ]
                      ))
                      .toList(),
                  ),
                )
              : Container(),
          )
        ]
      )
    );
  }
}