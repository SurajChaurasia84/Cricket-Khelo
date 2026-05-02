import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  final String? location;

  ProfileScreen({this.location});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final User? user = FirebaseAuth.instance.currentUser;
    final Color navyDark = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("MY PROFILE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            offset: Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmation(context, authService);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red[700], size: 20),
                    SizedBox(width: 10),
                    Text("Logout", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            icon: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: user != null ? firestoreService.getUser(user.uid) : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: navyDark));
          }

          final userData = snapshot.data;

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: navyDark,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white24,
                        backgroundImage: user?.photoURL != null 
                            ? NetworkImage(user!.photoURL!) 
                            : null,
                        child: user?.photoURL == null 
                            ? Icon(Icons.person, size: 60, color: Colors.white) 
                            : null,
                      ),
                      SizedBox(height: 16),
                      Text(
                        user?.displayName ?? "Player",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        user?.email ?? "",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildProfileItem(Icons.cake, "Age Group", userData?.ageGroup ?? "Not set", navyDark),
                      _buildProfileItem(
                        Icons.location_on, 
                        "Current Location", 
                        location ?? "Detecting...", 
                        navyDark
                      ),
                      _buildActionItem(
                        Icons.privacy_tip_outlined, 
                        "Privacy Policy", 
                        () => _launchURL("https://surajchaurasia84.github.io/Cricket-Khelo/privacy_policy/"), 
                        navyDark
                      ),
                      _buildActionItem(
                        Icons.share_rounded, 
                        "Share App", 
                        () => Share.share("Hey! Let's play cricket! 🏏\n\nJoin me on *Cricket Khelo* to find matches and players near you. Download now:\nhttps://play.google.com/store/apps/details?id=com.match.cricketkhelo.apps"),
                        navyDark
                      ),
                      _buildActionItem(
                        Icons.help_outline_rounded, 
                        "Help & Support", 
                        () => _launchURL("mailto:aakashkumarna26@gmail.com?subject=Help Support - Cricket Khelo"), 
                        navyDark
                      ),
                      SizedBox(height: 30),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Column(
                              children: [
                                Text(
                                  snapshot.data!.appName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w900, 
                                    color: navyDark.withOpacity(0.8),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Version ${snapshot.data!.version}",
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Logout?", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0A192F))),
        content: Text("Are you sure you want to logout from Cricket Khelo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await authService.signOut();
              Navigator.pop(context); // Back to login/home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, Color navyDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: navyDark, size: 22),
              SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyDark),
              ),
              Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _buildProfileItem(IconData icon, String label, String value, Color navyDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: navyDark),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  value, 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
