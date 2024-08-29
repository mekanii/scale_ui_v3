import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'globals.dart';

class CalibrationView extends StatefulWidget {
  const CalibrationView({super.key});

  @override
  CalibrationViewState createState() => CalibrationViewState();
}

class DoubleInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final number = double.tryParse(text);
    if (number == null) {
      return oldValue;
    }
    return newValue;
  }
}

class CalibrationViewState extends State<CalibrationView> {
  double _calibrationFactor = 0;

  bool _isCalibrationInit1 = false;
  bool _isCalibrationInit2 = false;
  bool _isCalibrationInit3 = false;
  bool _isCalibrationInit4 = false;
  bool _isCalibrationAborted = false;
  String _dot1 = '';
  String _dot2 = '';
  double _knownWeight = 0.0;

  @override
  void initState() {
    super.initState();
    portFlush();
    _reload();
  }

  Future<bool> _reload() async {
    bool status = false;

    try {
      final request = {
        'cmd': 13
      };

      await sendRequest(request).then((value) async => {
        await readResponse().then((response) async => {
          if (mounted) await notificationTrueFalse(context, response).then((result) => {
            status = result,
            if (result) setState(() {
              _calibrationFactor = json.decode(response)['data'];
            })
          })
        })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to get calibration factor: $e', false);
      }
      return false;
    }

    return status;
  }

  Future<bool> _initCalibration1() async {
    bool status = false;

    setState(() {
      _isCalibrationInit1 = false;
      _isCalibrationInit2 = false;
      _isCalibrationInit3 = false;
      _isCalibrationInit4 = false;
      _isCalibrationAborted = false;
      _dot1 = '';
      _dot2 = '';
      _knownWeight = 0.0;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _isCalibrationInit1 = true;
    });

    for (int i = 1; i <= 20; i++) {
      setState(() {
        _dot1 = '.' * i;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      final request = {
        'cmd': 10
      };

    await sendRequest(request).then((value) async => {
        await readResponse().then((response) async => {
          if (mounted) await notificationTrueFalse(context, response).then((result) => status = result)
        })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to initialize calibration: $e', false);
        return false;
      }
    }

    return status;
  }

  Future<bool> _initCalibration2() async {
    setState(() {
      _isCalibrationInit2 = true;
    });

    for (int i = 1; i <= 20; i++) {
      setState(() {
        _dot2 = '.' * i;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return true;
  }

  Future<bool> _createCalibrationFactor(double knownWeight) async {
    bool status = false;

    if (knownWeight > 0) {
      setState(() {
        _isCalibrationInit3 = true;
      });

      try {
        final request = {
            "cmd": 11,
            "data": {
                "knownWeight": knownWeight
            }
        };

      await sendRequest(request).then((value) async => {
          await readResponse().then((response) async => {
            if (mounted) await notificationTrueFalse(context, response).then((result) => {
              status = result,
              if (result) {
                setState(() {
                  _calibrationFactor = json.decode(response)['data'];
                  _isCalibrationInit4 = true;
                })
              } else {
                setState(() {
                  _isCalibrationAborted = true;
                })
              }
            })
          })
        });
      } catch (e) {
        if (mounted) {
          notification(context, 'Failed to initialize calibration: $e', false);
          setState(() {
            _isCalibrationAborted = true;
          });
          return false;
        }
      }
    } else {
      setState(() {
        _isCalibrationAborted = true;
      });
    }

    _reload();

    return status;
  }

  Future<void> _calibrate() async {
    await _initCalibration1().then((val1) => 
      _initCalibration2().then((val2) => {
        if (val2) _openDialogForKnownWeight()
      })
    );
  }

  Future<void> _openDialogForKnownWeight() async {
    final TextEditingController weightController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          buttonPadding: const EdgeInsets.all(16),
          title: const Text('Enter Known Weight'),
          content: Container(
            width: 350,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ListBody(
                children: <Widget>[
                  TextField(
                    controller: weightController,
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.end,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      DoubleInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Known Weight',
                      labelStyle: TextStyle(fontSize: 18),
                      suffixText: 'gr',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(fontSize: 18, color: Color.fromRGBO(183, 28, 28, 1))),
              onPressed: () {
                _createCalibrationFactor(_knownWeight);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _knownWeight = double.parse(weightController.text);
                  _createCalibrationFactor(_knownWeight);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Calibration',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 0, 0),
                child: Text('Current calibration factor:', style: TextStyle(fontSize: 24)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
                child: Text(_calibrationFactor.toStringAsFixed(2), style: const TextStyle(fontSize: 36)),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(size: 32, Icons.sync),
                title: const Text(
                  'Reload',
                  style: TextStyle(fontSize: 18),
                ),
                onTap: () => _reload(),
                tileColor: Colors.grey[200],
                splashColor: Colors.black12,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(size: 32, Icons.play_circle_outline),
                title: const Text(
                  'Start Calibration',
                  style: TextStyle(fontSize: 18),
                ),
                // onTap: () => _reload(),
                onTap: () => _calibrate(),
                tileColor: Colors.grey[200],
                splashColor: Colors.black12,
              ),
              const SizedBox(height: 16),
              _isCalibrationInit1 ?
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Initialize calibration.', style: TextStyle(fontSize: 18)),
                    const Text('Place the load cell on a level stable surface.', style: TextStyle(fontSize: 18)),
                    const Text('Remove any load applied to the load cell.', style: TextStyle(fontSize: 18)),
                    Text(_dot1, style: const TextStyle(fontSize: 18)),
                  ]
                ) : Container(),
              _isCalibrationInit2 ?
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Initialize complete.', style: TextStyle(fontSize: 18)),
                    const Text('Place **Known Weight** on the load cell.', style: TextStyle(fontSize: 18)),
                    Text(_dot2, style: const TextStyle(fontSize: 18)),
                  ]
                ) : Container(),
              _isCalibrationAborted == false ?
                _isCalibrationInit3 ?
                  Text('Known Weight set to: ${_knownWeight.toStringAsFixed(2)}.', style: const TextStyle(fontSize: 18))
                  : Container()
                : const Text('Calibration Aborted.', style: TextStyle(fontSize: 18)),
              _isCalibrationAborted == false ?
                _isCalibrationInit4 ?
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('New calibration factor has been set to: $_calibrationFactor.', style: const TextStyle(fontSize: 18)),
                      const Text('Calibration complete.', style: TextStyle(fontSize: 18)),
                    ]
                  ) : Container()
                : _isCalibrationInit3 ?
                  const Text('Calibration Aborted.', style: TextStyle(fontSize: 18))
                  : Container()
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container()
            ],
          ),
        ),
      ],
    );
  }
}