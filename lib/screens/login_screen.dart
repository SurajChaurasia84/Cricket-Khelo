import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedAgeGroup = "20+";

  Widget _buildAgeOption(String label, String value, Color navyDark) {
    bool isSelected = _selectedAgeGroup == value;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? navyDark : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedAgeGroup,
        onChanged: (val) {
          setState(() {
            _selectedAgeGroup = val!;
          });
        },
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? navyDark : Colors.grey[700],
          ),
        ),
        activeColor: navyDark,
        controlAffinity: ListTileControlAffinity.trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final Color navyDark = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative Background Element (Extreme Top Left)
          Positioned(
            top: -180,
            left: -180,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: navyDark.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative Background Element (Extreme Bottom Right)
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: navyDark.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  Spacer(flex: 2),
                  // Logo
                  Image.asset('assets/icon.png', height: 220, width: 220),
                  
                  Spacer(flex: 1),
                  
                  // Age Selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Select Your Age Group",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildAgeOption("Under 20", "Under20", navyDark),
                  _buildAgeOption("20+", "20+", navyDark),
                  
                  Spacer(flex: 2),
                  
                  // Bottom Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      await authService.signInWithGoogle();
                    },
                    icon: Image.asset('assets/google_logo.png', height: 20),
                    label: Text("Sign in with Google", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyDark,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: navyDark.withOpacity(0.4),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
