
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Alert',
      home: PriceAlertPage(),
    );
  }
}

class PriceAlertPage extends StatefulWidget {
  @override
  _PriceAlertPageState createState() => _PriceAlertPageState();
}

class _PriceAlertPageState extends State<PriceAlertPage> {
  final coins = ['BTC', 'ETH', 'SOL'];
  Map<String, double> thresholds = {'BTC': 1000, 'ETH': 50, 'SOL': 5};
  Map<String, double?> lastPrices = {'BTC': null, 'ETH': null, 'SOL': null};
  Map<String, bool> alertEnabled = {'BTC': true, 'ETH': true, 'SOL': true};
  List<String> alertHistory = [];
  FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initNotifications();
    Timer.periodic(Duration(minutes: 1), (_) => checkPrices());
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await notifications.initialize(settings);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (var coin in coins) {
      thresholds[coin] = prefs.getDouble('threshold_$coin') ?? thresholds[coin]!;
      alertEnabled[coin] = prefs.getBool('alert_$coin') ?? true;
    }
    setState(() {});
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (var coin in coins) {
      prefs.setDouble('threshold_$coin', thresholds[coin]!);
      prefs.setBool('alert_$coin', alertEnabled[coin]!);
    }
  }

  Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'crypto_channel',
      'Crypto Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await notifications.show(0, title, body, details);
  }

  Future<void> checkPrices() async {
    final response = await http.get(Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final prices = {
        'BTC': data['bitcoin']['usd'] * 1.0,
        'ETH': data['ethereum']['usd'] * 1.0,
        'SOL': data['solana']['usd'] * 1.0
      };
      prices.forEach((symbol, currentPrice) {
        final lastPrice = lastPrices[symbol];
        final threshold = thresholds[symbol]!;
        final enabled = alertEnabled[symbol]!;
        if (lastPrice != null && enabled) {
          final difference = (currentPrice - lastPrice).abs();
          if (difference >= threshold) {
            final msg = '$symbol changed \$${difference.toStringAsFixed(2)} to \$${currentPrice.toStringAsFixed(2)}';
            showNotification('$symbol Alert', msg);
            alertHistory.add('${DateTime.now().toLocal()} - $msg');
          }
        }
        lastPrices[symbol] = currentPrice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crypto Price Alerts')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ...coins.map((coin) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$coin Alert', style: TextStyle(fontSize: 18)),
                      Switch(
                        value: alertEnabled[coin]!,
                        onChanged: (val) {
                          setState(() => alertEnabled[coin] = val);
                          _savePreferences();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Notify every: \$'),
                      Expanded(
                        child: TextFormField(
                          initialValue: thresholds[coin]!.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final num = double.tryParse(val);
                            if (num != null) {
                              thresholds[coin] = num;
                              _savePreferences();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Divider()
                ],
              )),
          SizedBox(height: 20),
          Text('🔔 Alert History', style: TextStyle(fontWeight: FontWeight.bold)),
          ...alertHistory.reversed.map((entry) => Text(entry)).take(10)
        ],
      ),
    );
  }
}
