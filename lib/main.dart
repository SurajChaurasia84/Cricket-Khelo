import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Request Permissions
  await _requestInitialPermissions();

  // Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.initNotifications();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<NotificationService>(create: (_) => notificationService),
      ],
      child: MyApp(),
    ),
  );
}

Future<void> _requestInitialPermissions() async {
  // Request Location
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.notification,
  ].request();

  if (statuses[Permission.location]!.isDenied) {
    print("Location permission denied");
  }
  if (statuses[Permission.notification]!.isDenied) {
    print("Notification permission denied");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Khelo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF0A192F), // Dark Navy Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF0A192F),
          primary: Color(0xFF0A192F),
        ),
        useMaterial3: true,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final notificationService = Provider.of<NotificationService>(context);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          } else {
            // Update user info in background
            _updateUserInfo(user, firestoreService, notificationService);
            return HomeScreen();
          }
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Future<void> _updateUserInfo(User user, FirestoreService firestore, NotificationService notifications) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      String? token = await notifications.getToken();
      
      // Default age group if not already set
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
