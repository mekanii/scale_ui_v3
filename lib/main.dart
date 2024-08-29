import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:provider/provider.dart';
import 'globals.dart';
import 'summary.dart';
import 'scale.dart';
import 'parts.dart';
import 'calibration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Set the window to full screen
  await windowManager.setFullScreen(true);
  runApp(
    ChangeNotifierProvider(
      create: (context) => PortProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scale UI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Scale UI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  String _connectButtonText = 'Connect';
  Color _connectButtonColor = Colors.blueGrey;

  final List<Widget> _views = [
    SummaryView(),
    ScaleView(),
    PartsView(),
    CalibrationView(),
    // PartsView(),
    // SummaryView(),
    // CalibrationView(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    detectUsbHotPlug(context);
  }

  @override
  Widget build(BuildContext context) {
    final portProvider = Provider.of<PortProvider>(context);

    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            width: 350,
            color: Colors.black12,
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const SizedBox(height: 48),
                DropdownButton<SerialPort>(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  isExpanded: true,
                  value: port,
                  hint: const Text('Select Port'),
                  icon: const Icon(Icons.arrow_drop_down),
                  iconSize: 24,
                  elevation: 16,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                  focusColor: Colors.transparent,
                  underline: Container(
                    height: 1,
                    color: Colors.grey,
                  ),
                  onChanged: (SerialPort? newValue) {
                    setState(() {
                      port = newValue!;
                    });
                    isFocused = false;
                  },
                  onTap: () => isFocused = true,
                  items: portProvider.ports?.map<DropdownMenuItem<SerialPort>>((SerialPort port) {
                    return DropdownMenuItem<SerialPort>(
                      value: port,
                      child: Text(port.name ?? ''),
                    );
                  }).toList(),
                ),
                TextButton.icon(
                  icon: const Icon(size: 32, Icons.cast_connected),
                  label: Row(
                    children: [
                      const SizedBox(width: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_connectButtonText, style: const TextStyle(fontSize: 18)),
                      ),
                    ]
                  ),
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    alignment: Alignment.centerLeft,
                    backgroundColor: _connectButtonColor,
                    foregroundColor: Colors.white
                  ),
                  onPressed: () async {
                    if (_connectButtonText == 'Connect') {
                      if (port != null) {
                        final result = await open();
                        if (result['status']) {
                          setState(() {
                            _connectButtonText = 'Disconnect';
                            _connectButtonColor = Theme.of(context).colorScheme.error;
                          });
                          if (mounted) {
                            notification(context, 'Successfully connected to the port', true);
                          }
                        } else {
                          final String error = result['error']; 
                          if (mounted) {
                            notification(context, 'Failed to connect to the port: $error', false);
                          }
                        }
                      } else {
                        notification(context, 'Please select a port first', false);
                      }
                    } else {
                      await close();
                      setState(() {
                        _connectButtonText = 'Connect';
                        _connectButtonColor = Colors.blueGrey;
                      });
                      _onItemTapped(0);
                    }
                  },
                ),
                const SizedBox(height: 32),
                _buildListTile(0, Icons.backup_table, 'Summary'),
                _buildListTile(1, Icons.monitor_weight_outlined, 'Scale'),
                const ListTile(
                  title: Text(
                    'Settings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildListTile(2, Icons.list, 'Parts'),
                _buildListTile(3, Icons.ads_click_sharp, 'Calibration'),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                child: _views[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(int index, IconData icon, String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _connectButtonText == 'Disconnect' ? () => _onItemTapped(index) : () => {},
        child: Stack(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              leading: Icon(size: 32, icon),
              title: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            if (_selectedIndex == index)
              Positioned(
                left: 0,
                top: 16,
                bottom: 16,
                child: Container(
                  width: 10,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}