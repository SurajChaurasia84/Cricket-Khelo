import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/invite_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class InviteForm extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String ageGroup;

  InviteForm({this.lat, this.lng, required this.ageGroup});

  @override
  _InviteFormState createState() => _InviteFormState();
}

class _InviteFormState extends State<InviteForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController(text: "Detecting address...");
  int _playersRequired = 1;
  String _message = "";
  double? _currentLat;
  double? _currentLng;
  bool _isFetchingLocation = false;
  bool _isEditingAddress = false;
  String _userName = "User";
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.lat;
    _currentLng = widget.lng;
    
    _loadUserData();

    if (_currentLat != null && _currentLng != null) {
      _getAddressFromLatLng(_currentLat!, _currentLng!);
    } else {
      _fetchLocation();
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Priority 1: FirebaseAuth display name
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        setState(() {
          _userName = user.displayName!;
          _userPhoto = user.photoURL;
        });
      }
      
      // Priority 2: Firestore data (more reliable)
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      UserModel? userData = await firestoreService.getUser(user.uid);
      if (userData != null && mounted) {
        setState(() {
          _userName = userData.name;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _addressController.text = "Detecting location...";
    });
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
        });
        await _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _addressController.text = "GPS Signal Weak. Tap to type address.";
        });
      }
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    setState(() => _isFetchingLocation = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (mounted && placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String formattedAddress = [
          place.subLocality,
          place.locality,
          place.administrativeArea
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        
        setState(() {
          _addressController.text = formattedAddress.isEmpty ? "Location pinned" : formattedAddress;
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressController.text = "Tap to enter address manually";
          _isFetchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = FirebaseAuth.instance.currentUser;
    final Color navyDark = Color(0xFF0A192F);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 20,
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
              "CREATE MATCH INVITE",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navyDark, letterSpacing: 1.1),
            ),
            Text(
              "Age Group: ${widget.ageGroup}",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            
            // Interactive Location Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Match Location",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      if (!_isEditingAddress)
                        IconButton(
                          constraints: BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.edit, size: 16, color: navyDark),
                          onPressed: () => setState(() => _isEditingAddress = true),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_isEditingAddress)
                    TextField(
                      controller: _addressController,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Enter area, city (e.g. Sec 22, Delhi)",
                        suffixIcon: IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => setState(() => _isEditingAddress = false),
                        ),
                      ),
                      onSubmitted: (_) => setState(() => _isEditingAddress = false),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _isEditingAddress = true),
                      child: Text(
                        _addressController.text,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: navyDark),
                      ),
                    ),
                  if (_isFetchingLocation && !_isEditingAddress)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.blue[100], color: Colors.blue),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            TextFormField(
              decoration: InputDecoration(
                labelText: "Players Required",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.group),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty ? "Required" : null,
              onChanged: (val) => _playersRequired = int.tryParse(val) ?? 1,
            ),
            SizedBox(height: 16),
            TextFormField(
              textCapitalization: TextCapitalization.sentences, // Capitalizes first letter
              maxLength: 100, // Character limit to prevent abuse
              decoration: InputDecoration(
                labelText: "Message (Optional)",
                hintText: "e.g., We need a good wicket keeper!",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.message),
                filled: true,
                fillColor: Colors.grey[50],
                counterStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              minLines: 1,
              maxLines: 2,
              onChanged: (val) => _message = val,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: navyDark,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: (_isFetchingLocation || _currentLat == null) ? null : () async {
                if (_formKey.currentState!.validate()) {
                  final invite = InviteModel(
                    inviteId: '',
                    createdBy: user?.uid ?? 'unknown',
                    creatorName: _userName, // Using fetched name
                    creatorPhoto: _userPhoto,
                    playersRequired: _playersRequired,
                    message: _message,
                    ageGroup: widget.ageGroup,
                    address: _addressController.text, // Saving the confirmed address
                    lat: _currentLat!,
                    lng: _currentLng!,
                    timestamp: DateTime.now(),
                  );
                  await firestoreService.createInvite(invite);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Match Invite Published!"),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                }
              },
              child: _isFetchingLocation 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : Text("PUBLISH INVITE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
