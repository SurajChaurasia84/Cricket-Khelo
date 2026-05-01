import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedAgeGroup = "20+";

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final Color navyDark = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_cricket, size: 100, color: navyDark),
              SizedBox(height: 24),
              Text(
                "Cricket Khelo",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: navyDark,
                ),
              ),
              SizedBox(height: 48),
              DropdownButtonFormField<String>(
                value: _selectedAgeGroup,
                decoration: InputDecoration(
                  labelText: "Select Your Age Group",
                  labelStyle: TextStyle(color: navyDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: navyDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: navyDark, width: 2),
                  ),
                ),
                items: ["Under20", "20+"]
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAgeGroup = value!;
                  });
                },
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await authService.signInWithGoogle();
                },
                icon: Icon(Icons.login),
                label: Text("Sign in with Google", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyDark,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
