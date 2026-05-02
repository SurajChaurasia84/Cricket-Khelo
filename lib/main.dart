import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'models/user_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Make Status Bar seamless with the UI
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Transparent status bar
    statusBarIconBrightness: Brightness.light, // White icons for dark theme
    systemNavigationBarColor: Color(0xFF0A192F), // Match bottom nav with Navy
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  NotificationService? notificationService;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Offline Persistence for Realtime Database (Chat)
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB
    
    // Configure Firestore for persistent caching
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Register Background Notification Handler
    FirebaseMessaging.onBackgroundMessage(NotificationService.handleBackgroundMessage);

    notificationService = NotificationService();
  } catch (e) {
    print("Firebase init error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<NotificationService?>(create: (_) => notificationService),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Khelo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: Color(0xFF0A192F),
        scaffoldBackgroundColor: Color(0xFFF1F5F9),
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light, // Ensure white icons on AppBar
          backgroundColor: Color(0xFF0A192F),
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF0A192F),
          primary: Color(0xFF0A192F),
          surface: Color(0xFF0A192F),
        ),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => AuthWrapper(),
      },
      initialRoute: '/',
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Set a timeout for permission requests to prevent sticking on loader
      await [
        Permission.location,
        Permission.notification,
      ].request().timeout(const Duration(seconds: 10), onTimeout: () {
        print("Permission request timed out");
        return {};
      });
    } catch (e) {
      print("Permission error: $e");
    }

    try {
      final notificationService = Provider.of<NotificationService?>(context, listen: false);
      if (notificationService != null) {
        await notificationService.initNotifications().timeout(const Duration(seconds: 5));
      }

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    } catch (e) {
      print("Service init error: $e");
    }
    
    if (mounted) {
      setState(() {
        _permissionsRequested = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final notificationService = Provider.of<NotificationService?>(context);

    if (!_permissionsRequested) {
      return Scaffold(
        backgroundColor: Color(0xFF0A192F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          } else {
            if (notificationService != null) {
              _updateUserInfo(user, firestoreService, notificationService);
            }
            return HomeScreen();
          }
        }
        return Scaffold(
          backgroundColor: Color(0xFF0A192F),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }

  Future<void> _updateUserInfo(User user, FirestoreService firestore, NotificationService notifications) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      String? token = await notifications.getToken();
      
      UserModel? existingUser = await firestore.getUser(user.uid);
      String ageGroup = existingUser?.ageGroup ?? "20+";

      UserModel userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? "Player",
        email: user.email ?? "",
        photoUrl: user.photoURL ?? "",
        ageGroup: ageGroup,
        lat: position.latitude,
        lng: position.longitude,
        fcmToken: token ?? "",
      );
      await firestore.saveUser(userModel);
    } catch (e) {
      print("Error updating user info: $e");
    }
  }
}
