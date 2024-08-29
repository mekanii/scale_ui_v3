import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'globals.dart';

class PartsView extends StatefulWidget {
  const PartsView({super.key});

  @override
  PartsViewState createState() => PartsViewState();
}

class Part {
  int id;
  String name;
  double std;
  String unit;
  double hysteresis;
  bool isExpanded;

  Part({
    required this.id,
    required this.name,
    required this.std,
    required this.unit,
    required this.hysteresis,
    this.isExpanded = false,
  });
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
  
class PartsViewState extends State<PartsView> {
  int _partCount = 0;
  List<Part> _parts = [];
  int _expandedIndex = -1;
  bool _isReloadEnabled = false;

  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    portFlush();
    _reload();
  }

  Future<void> _reload() async {
    bool status = await _fetchParts();

    setState(() {
      _isReloadEnabled = status;
      _expandedIndex = -1;
    });
  }

  Future<bool> _fetchParts() async {
    String message = '';
    bool status = false;

    setState(() {
      _parts = [];
      _partCount = 0;
    });

    try {
      final request = {
        'cmd': 1
      };
      await sendRequest(request);
      final response = await readResponse();
      final responseData = json.decode(response);
      final List<dynamic> data = responseData['data'];
      message = responseData['message'];

      if (responseData['status'] == 200) {
        status = true;
        setState(() {
          _parts = data.map((part) => Part(
            id: part['id'],
            name: part['name'],
            std: part['std'].toDouble(),
            unit: part['unit'],
            hysteresis: part['hysteresis'].toDouble(),
            isExpanded: false,
          )).toList();

          _partCount = _parts.length;
        });

        if (mounted) {
          notification(context, message, status);
        }
      } else {
        status = false;
        if (mounted) {
          notification(context, message, status);
        }
      }
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to load parts: $e', status);
      }
    }

    return status;
  }

  Future<void> _create(String name, double std, String unit, double hysteresis) async {
    setState(() {
      _parts = [];
      _partCount = 0;
    });

    try {
      final request = {
        "cmd": 4,
        "data": {
            "name": name,
            "std": unit == 'kg' ? std / 1000 : std,
            "unit": unit,
            "hysteresis": hysteresis
        }
      };
      await sendRequest(request).then((value) async => {
        await readResponse().then((response) => { if (mounted) notificationTrueFalse(context, response) })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to add part standard: $e', false);
      }
    }

    await _reload();
  }

  Future<void> _update(Part oldPart, Part newPart) async {
    setState(() {
      _parts = [];
      _partCount = 0;
    });

    try {
      final request = {
        "cmd": 5,
        "data": {
            "id": oldPart.id,
            "name": newPart.name,
            "std": newPart.unit == 'kg' ? newPart.std / 1000 : newPart.std,
            "unit": newPart.unit,
            "hysteresis": newPart.hysteresis
        }
      };
      await sendRequest(request).then((value) async => {
        await readResponse().then((response) => { if (mounted) notificationTrueFalse(context, response) })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to add part standard: $e', false);
      }
    }

    await _reload();
  }

  Future<void> _delete(Part part) async {
    setState(() {
      _parts = [];
      _partCount = 0;
    });

    try {
      final request = {
        "cmd": 6,
        "data": {
            "id": part.id,
        }
      };
      await sendRequest(request).then((value) async => {
        await readResponse().then((response) => { if (mounted) notificationTrueFalse(context, response) })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to delete part standard: $e', false);
      }
    }

    _reload();
  }

  Future<double> _measure() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    double data = 0.0;

    try {
      final request = {
        "cmd": 9
      };
      await sendRequest(request).then((value) async => {
        await readResponse().then((response) async => {
          if (mounted) await notificationTrueFalse(context, response).then((result) => {
            if (result) data = json.decode(response)['data']
          })
        })
      });
    } catch (e) {
      if (mounted) {
        notification(context, 'Failed to get stable weight: $e', false);
      }
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }

    return data;
  }

  Future<void> _openDialog({Part? part}) async {
    final TextEditingController nameController = TextEditingController(text: part?.name ?? '');
    final TextEditingController stdController = TextEditingController(
      text: part?.unit == 'kg' ? ((part?.std ?? 0) * 1000).toStringAsFixed(0) : (part?.std ?? 0).toStringAsFixed(0)
    );
    final TextEditingController hysteresisController = TextEditingController(text: part?.hysteresis.toStringAsFixed(2) ?? '');

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        String unitController = part?.unit ?? '';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              buttonPadding: const EdgeInsets.all(16),
              title: const Text('Enter Part Standard'),
              content: Container(
                width: 350,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ListBody(
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(
                          labelText: 'Part Name',
                          labelStyle: TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stdController,
                              style: const TextStyle(fontSize: 20),
                              textAlign: TextAlign.end,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                DoubleInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Standard Weight',
                                suffixText: 'gr',
                                labelStyle: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.black45,
                                ),
                                child: _isLoading 
                                  ? const SizedBox(
                                      width: 16, // Set desired width
                                      height: 16, // Set desired height
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Get Weight',
                                      style: TextStyle(fontSize: 18, color: Colors.white),
                                    ),
                                onPressed: () {
                                  if (!_isLoading) { // Prevent multiple taps
                                    setState(() {
                                      _isLoading = true; // Start loading
                                    });
                                    _measure().then((value) {
                                      stdController.text = value.toStringAsFixed(0);
                                      setState(() {
                                        _isLoading = false; // Stop loading
                                      });
                                    });
                                  }
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Unit',
                        style: TextStyle(fontSize: 18),
                      ),
                      RadioListTile(
                        title: const Text(
                          'gr',
                          style: TextStyle(fontSize: 18),
                        ),
                        value: 'gr',
                        groupValue: unitController,
                        onChanged: (value) {
                          setState(() {
                            unitController = value!;
                          });
                        },
                      ),
                      RadioListTile(
                        title: const Text(
                          'kg',
                          style: TextStyle(fontSize: 18),
                        ),
                        value: 'kg',
                        groupValue: unitController,
                        onChanged: (value) {
                          setState(() {
                            unitController = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hysteresisController,
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.end,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          DoubleInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Tolerance',
                          labelStyle: TextStyle(fontSize: 18),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 18, color: Color.fromRGBO(183, 28, 28, 1)),
                  ),
                  onPressed: () {
                    if (!_isLoading) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                TextButton(
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    if (!_isLoading) {
                      if (part != null) {
                        await _update(part, Part(id: part.id, name: nameController.text, std: double.parse(stdController.text), unit: unitController, hysteresis: double.parse(hysteresisController.text)));
                      } else {
                        await _create(nameController.text, double.parse(stdController.text), unitController, double.parse(hysteresisController.text));
                      }
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDeleteDialog({Part? part}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Part Standard'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete this part standard?',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 18, color: Color.fromRGBO(183, 28, 28, 1)),
              ),
              onPressed: () {
                if (part != null) {
                  _delete(part);
                }
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
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Part Standards',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  // contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(size: 32, Icons.add_box_outlined),
                  title: const Text(
                    'Add Part Standard',
                    style: TextStyle(fontSize: 18),
                  ),
                  // subtitle: const Text(
                  //   'See IP Address on device Settings',
                  //   style: TextStyle(fontSize: 16),
                  // ),
                  onTap: _isReloadEnabled ? () => _openDialog() : () => {},
                  tileColor: Colors.grey[200],
                  splashColor: Colors.black12,
                ),
                const SizedBox(height: 16),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                  child: Text('Found: $_partCount standards', style: const TextStyle(fontSize: 20)),
                ),
                ExpansionPanelList(
                  expandedHeaderPadding: const EdgeInsets.all(0),
                  elevation: 0,
                  dividerColor: Colors.transparent,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      if (_expandedIndex == index) {
                        _parts[_expandedIndex].isExpanded = false;
                          
                        setState(() {
                          _expandedIndex = -1;
                        });
                      } else {
                        if (_expandedIndex != -1) {
                          _parts[_expandedIndex].isExpanded = false;
                        }
                        
                        _parts[index].isExpanded = true;
                        setState(() {
                          _expandedIndex = index;
                        });
                      }
                    });
                  },
                  children: _parts.map<ExpansionPanel>((Part part) {
                    return ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text(
                            part.name,
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: Text(
                            '${part.unit == 'gr' ? part.std.toStringAsFixed(0) : part.std.toStringAsFixed(2)} ${part.unit}\nTolerance: ${part.hysteresis.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      },
                      body: Row(
                        children: [
                          Expanded(child: Container()),
                          Expanded(
                            child: Column(
                              children: [
                                ListTile(
                                  title: const Text(
                                    'Modify',
                                    style: TextStyle(fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  onTap: () => _openDialog(part: part),
                                  tileColor: Colors.grey[200],
                                  splashColor: Colors.black12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                ListTile(
                                  title: const Text(
                                    'Delete',
                                    style: TextStyle(fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  onTap: () => _openDeleteDialog(part: part),
                                  tileColor: Colors.grey[200],
                                  splashColor: Colors.black12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      canTapOnHeader: true,
                      isExpanded: part.isExpanded,
                    );
                  }).toList(),
                ),
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
      )
    );
  }
}