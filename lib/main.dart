import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

// -----------------------------------------------------------------------------
// [BACKGROUND WORKER]
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('saved_uid');
      final region = prefs.getString('preferred_region') ?? 'us';

      if (uid == null) return Future.value(true);

      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wishlist')
          .get();

      if (wishlistSnapshot.docs.isEmpty) return Future.value(true);

      const apiKey = 'WczQJnECVdUuEmWofaos0nglsMuia1-k';
      int notificationId = 0;

      for (var doc in wishlistSnapshot.docs) {
        final data = doc.data();
        final steamAppId = data['steamAppId'];
        final savedPrice = data['currentPriceNum']?.toDouble() ?? 0.0;
        final title = data['title'] ?? 'A game on your wishlist';

        final url = Uri.parse(
            'https://api.gg.deals/v1/prices/by-steam-app-id/?ids=$steamAppId&key=$apiKey&region=$region');

        final response =
            await http.get(url, headers: {'Accept': 'application/json'});
        if (response.statusCode == 200) {
          final root = jsonDecode(response.body);
          final gameEntry = root['data']?[steamAppId];

          if (gameEntry != null && gameEntry['prices'] != null) {
            final prices = gameEntry['prices'];

            final currentRetailRaw = prices['currentRetail'];
            double newPrice = currentRetailRaw != null
                ? double.tryParse(currentRetailRaw.toString()) ?? 0.0
                : 0.0;
            final currency = prices['currency'] ?? 'USD';

            if (newPrice > 0 && newPrice < savedPrice) {
              const AndroidNotificationDetails androidPlatformChannelSpecifics =
                  AndroidNotificationDetails(
                'price_drops',
                'Price Drops',
                channelDescription: 'Notifications for wishlist price drops',
                importance: Importance.max,
                priority: Priority.high,
              );
              const NotificationDetails platformChannelSpecifics =
                  NotificationDetails(android: androidPlatformChannelSpecifics);

              await flutterLocalNotificationsPlugin.show(
                notificationId++,
                'Price Drop Alert! 📉',
                '$title dropped from $savedPrice to $newPrice $currency!',
                platformChannelSpecifics,
              );

              await doc.reference.update({
                'currentPriceNum': newPrice,
                'price': '$newPrice $currency',
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Background Task Error: $e");
    }
    return Future.value(true);
  });
}

// -----------------------------------------------------------------------------
// [MAIN APP APP]
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "YOUR_API_KEY",
        authDomain: "YOUR_AUTH_DOMAIN",
        projectId: "YOUR_PROJECT_ID",
        storageBucket: "YOUR_STORAGE_BUCKET",
        messagingSenderId: "YOUR_SENDER_ID",
        appId: "YOUR_APP_ID",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  if (!kIsWeb) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  runApp(const WishlistApp());
}

class WishlistApp extends StatelessWidget {
  const WishlistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wishlist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF171A21),
        scaffoldBackgroundColor: const Color(0xFF1B2838),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171A21),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
    _signInAnonymously();
  }

  Future<void> _requestNotificationPermissions() async {
    if (!kIsWeb) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCred.user!.uid;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_uid', uid);

      if (!kIsWeb) {
        Workmanager().registerPeriodicTask(
          "price_check_task",
          "checkPrices",
          frequency: const Duration(hours: 24),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF66C0F4))));
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const Scaffold(body: Center(child: Text('Authenticating...')));
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  final String _ggDealsApiKey = 'WczQJnECVdUuEmWofaos0nglsMuia1-k';

  String _currentManualInput = '';
  TextEditingController? _autoCompleteController;

  String _selectedRegion = 'us';
  final Map<String, String> _availableRegions = {
    'us': 'USD',
    'gb': 'GBP',
    'eu': 'EUR',
    'br': 'BRL',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedRegion();
  }

  Future<void> _loadSavedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRegion = prefs.getString('preferred_region');
    if (savedRegion != null && _availableRegions.containsKey(savedRegion)) {
      setState(() {
        _selectedRegion = savedRegion;
      });
    }
  }

  Future<void> _saveRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_region', region);
  }

  Future<List<Map<String, dynamic>>> _searchSteamGames(String query) async {
    if (query.isEmpty) return [];
    try {
      final url = Uri.parse(
          'https://store.steampowered.com/api/storesearch/?term=$query&l=english&cc=US');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        return items
            .map(
                (e) => {'id': e['id'].toString(), 'name': e['name'].toString()})
            .toList();
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
    return [];
  }

  // [NEW] Function to safely open URLs
  Future<void> _launchGameUrl(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint("Launch error: $e");
    }
  }

  Future<void> _fetchAndSaveDeal(String rawSteamAppId) async {
    final steamAppId = rawSteamAppId.trim();
    if (steamAppId.isEmpty || int.tryParse(steamAppId) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric Steam ID.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://api.gg.deals/v1/prices/by-steam-app-id/?ids=$steamAppId&key=$_ggDealsApiKey&region=$_selectedRegion');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Status ${response.statusCode}\nServer says: ${response.body}');
      }

      final Map<String, dynamic> root = jsonDecode(response.body);
      final gameEntry = root['data']?[steamAppId];

      if (gameEntry == null) {
        throw Exception('Game not found in GG.deals database.');
      }

      final prices = gameEntry['prices'];
      if (prices == null) {
        throw Exception('Game found, but no pricing data is available.');
      }

      final currentRetailRaw = prices['currentRetail'];
      final historicalRetailRaw = prices['historicalRetail'];
      final currency = prices['currency'] ?? _availableRegions[_selectedRegion];

      double currentPriceNum = currentRetailRaw != null
          ? double.tryParse(currentRetailRaw.toString()) ?? 0.0
          : 0.0;
      double historicalLowNum = historicalRetailRaw != null
          ? double.tryParse(historicalRetailRaw.toString()) ?? 0.0
          : 0.0;

      final currentPriceDisplay = currentRetailRaw ?? 'N/A';

      double priceDiff = currentPriceNum - historicalLowNum;
      if (priceDiff < 0) priceDiff = 0.0;

      String? headerImage;
      try {
        final steamUrl = Uri.parse(
            'https://store.steampowered.com/api/appdetails?appids=$steamAppId');
        final steamRes = await http.get(steamUrl);
        if (steamRes.statusCode == 200) {
          final steamData = jsonDecode(steamRes.body);
          if (steamData[steamAppId] != null &&
              steamData[steamAppId]['success'] == true) {
            headerImage = steamData[steamAppId]['data']['header_image'];
          }
        }
      } catch (e) {
        debugPrint("Image fetch error: $e");
      }

      final gameData = {
        'steamAppId': steamAppId,
        'title': gameEntry['title'] ?? 'Unknown Game',
        'price': '$currentPriceDisplay $currency',
        'currentPriceNum': currentPriceNum,
        'historicalLowNum': historicalLowNum,
        'priceDiff': priceDiff,
        'currency': currency,
        'headerImage': headerImage ?? '',
        'url': gameEntry['url'] ?? '',
        'regionSavedAs': _selectedRegion,
        'added_at': FieldValue.serverTimestamp(),
      };

      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(steamAppId)
          .set(gameData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${gameEntry['title'] ?? 'Game'} added to Wishlist!'),
            backgroundColor: const Color(0xFF66C0F4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2A475E),
            title: const Text('API Error Details',
                style: TextStyle(color: Colors.redAccent)),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.videogame_asset,
                    size: 32, color: Color(0xFF66C0F4));
              },
            ),
            const SizedBox(width: 12),
            const Text('STEAM DEALS'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRegion,
                dropdownColor: const Color(0xFF2A475E),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedRegion = newValue;
                    });
                    _saveRegion(newValue);
                  }
                },
                items: _availableRegions.entries
                    .map<DropdownMenuItem<String>>((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF171A21),
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => option['name'],
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return await _searchSteamGames(textEditingValue.text);
                    },
                    onSelected: (Map<String, dynamic> selection) {
                      FocusScope.of(context).unfocus();
                      _autoCompleteController?.clear();
                      _currentManualInput = '';
                      _fetchAndSaveDeal(selection['id']);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                      _autoCompleteController = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) => _currentManualInput = value,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Search Title or Enter App ID',
                          labelStyle: const TextStyle(color: Colors.white54),
                          hintText: 'e.g. Portal 2 or 620',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF2A475E),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 100,
                            margin: const EdgeInsets.only(top: 8.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A475E),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                )
                              ],
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option['name'],
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  subtitle: Text('ID: ${option['id']}',
                                      style: const TextStyle(
                                          color: Colors.white54)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66C0F4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _fetchAndSaveDeal(_currentManualInput);
                            _autoCompleteController?.clear();
                            _currentManualInput = '';
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('ADD',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: userId == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF66C0F4)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('wishlist')
                        .orderBy('added_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF66C0F4)));
                      }

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videogame_asset_outlined,
                                  size: 80,
                                  color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'Your wishlist is empty.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Search a game above to start tracking.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final docId = docs[index].id;

                          final imageUrl = data['headerImage'] ?? '';
                          final currentPriceNum =
                              data['currentPriceNum']?.toDouble() ?? 0.0;
                          final historicalLowNum =
                              data['historicalLowNum']?.toDouble() ?? 0.0;
                          final priceDiff =
                              data['priceDiff']?.toDouble() ?? 0.0;
                          final currency = data['currency'] ?? 'USD';
                          final ggDealsUrl = data['url'] ?? '';

                          return Dismissible(
                            key: Key(docId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 30),
                            ),
                            onDismissed: (direction) {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('wishlist')
                                  .doc(docId)
                                  .delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${data['title']} removed.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _launchGameUrl(ggDealsUrl),
                              child: Container(
                                height: 130,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A475E),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                  image: imageUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover,
                                          colorFilter: ColorFilter.mode(
                                            const Color(0xFF1B2838)
                                                .withValues(alpha: 0.85),
                                            BlendMode.darken,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    data['title'],
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              color:
                                                                  Colors.black,
                                                              blurRadius: 4)
                                                        ]),
                                                  ),
                                                ),
                                                const Icon(Icons.open_in_new,
                                                    size: 16,
                                                    color: Colors.white38),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'App ID: ${data['steamAppId']}',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            currentPriceNum == 0.0
                                                ? 'FREE'
                                                : '${currentPriceNum.toStringAsFixed(2)} $currency',
                                            style: const TextStyle(
                                                color: Color(0xFF66C0F4),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                                shadows: [
                                                  Shadow(
                                                      color: Colors.black,
                                                      blurRadius: 4)
                                                ]),
                                          ),
                                          const SizedBox(height: 4),
                                          if (historicalLowNum > 0)
                                            Text(
                                              'Hist. Low: ${historicalLowNum.toStringAsFixed(2)} $currency',
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12),
                                            ),
                                          if (priceDiff > 0)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '+${priceDiff.toStringAsFixed(2)} from low',
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 10),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
