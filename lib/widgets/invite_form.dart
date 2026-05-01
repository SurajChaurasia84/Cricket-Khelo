import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/invite_model.dart';
import '../services/firestore_service.dart';

class InviteForm extends StatefulWidget {
  final double lat;
  final double lng;
  final String ageGroup;

  InviteForm({required this.lat, required this.lng, required this.ageGroup});

  @override
  _InviteFormState createState() => _InviteFormState();
}

class _InviteFormState extends State<InviteForm> {
  final _formKey = GlobalKey<FormState>();
  int _playersRequired = 1;
  String _message = "";

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    // final user = FirebaseAuth.instance.currentUser; // Bypassed for preview
    final user = null; 

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Create Match Invite (${widget.ageGroup})",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(labelText: "Players Required"),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty ? "Enter number" : null,
              onChanged: (val) => _playersRequired = int.tryParse(val) ?? 1,
            ),
            SizedBox(height: 10),
            TextFormField(
              decoration: InputDecoration(labelText: "Optional Message"),
              onChanged: (val) => _message = val,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0A192F),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final invite = InviteModel(
                    inviteId: '',
                    createdBy: user?.uid ?? 'unknown',
                    playersRequired: _playersRequired,
                    message: _message,
                    ageGroup: widget.ageGroup,
                    lat: widget.lat,
                    lng: widget.lng,
                    timestamp: DateTime.now(),
                  );
                  await firestoreService.createInvite(invite);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Invite Created!")),
                  );
                }
              },
              child: Text("Submit Invite"),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
