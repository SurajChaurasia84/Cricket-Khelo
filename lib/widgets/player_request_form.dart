import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/player_request_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class PlayerRequestForm extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String ageGroup;

  PlayerRequestForm({this.lat, this.lng, required this.ageGroup});

  @override
  _PlayerRequestFormState createState() => _PlayerRequestFormState();
}

class _PlayerRequestFormState extends State<PlayerRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController(text: "Detecting address...");
  final TextEditingController _messageController = TextEditingController();
  int _playersAvailable = 1;
  double? _currentLat;
  double? _currentLng;
  bool _isFetchingLocation = false;
  bool _isEditingAddress = false;
  String _userName = "User";
  String? _userPhoto;
  bool _isPublishing = false;

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
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        setState(() {
          _userName = user.displayName!;
          _userPhoto = user.photoURL;
        });
      }
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      UserModel? userData = await firestoreService.getUser(user.uid);
      if (userData != null && mounted) {
        setState(() {
          _userName = userData.name;
        });
      }
    }
  }

  Future<void> _fetchLocation() async {
    if (mounted) setState(() {
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
    if (mounted) setState(() => _isFetchingLocation = true);
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
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    "POST PLAYER AVAILABILITY",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navyDark, letterSpacing: 1.1),
                  ),
                  Text(
                    "Looking for match in ${widget.ageGroup}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Location Selection (Blue theme like InviteForm)
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
                            "My Location",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      IconButton(
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit, size: 16, color: navyDark),
                        onPressed: () => setState(() => _isEditingAddress = !_isEditingAddress),
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
                        hintText: "Enter area (e.g. Sec 22, Delhi)",
                      ),
                    )
                  else
                    Text(
                      _addressController.text,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: navyDark),
                    ),
                  if (_isFetchingLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.blue[100], color: Colors.blue),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            // Players Available (Matches InviteForm style)
            TextFormField(
              decoration: InputDecoration(
                labelText: "Players Available",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.group),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              initialValue: "1",
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty ? "Required" : null,
              onChanged: (val) => _playersAvailable = int.tryParse(val) ?? 1,
            ),
            SizedBox(height: 16),
            // Message Field (Matches InviteForm style)
            TextFormField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: "Message (Optional)",
                hintText: "e.g., Fast bowler available for weekend match.",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.message),
                filled: true,
                fillColor: Colors.grey[50],
                counterStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: navyDark,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: (_isPublishing || _currentLat == null) ? null : () async {
                setState(() => _isPublishing = true);
                final request = PlayerRequestModel(
                  requestId: '',
                  playerId: user?.uid ?? 'unknown',
                  playerName: _userName,
                  playerPhoto: _userPhoto,
                  message: _messageController.text,
                  playersAvailable: _playersAvailable,
                  ageGroup: widget.ageGroup,
                  address: _addressController.text,
                  lat: _currentLat!,
                  lng: _currentLng!,
                  timestamp: DateTime.now(),
                );
                final messenger = ScaffoldMessenger.of(context);
                
                // Pop FIRST for instant UI response
                Navigator.pop(context);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Availability Posted! Matches will find you."),
                    backgroundColor: navyDark,
                  ),
                );

                await firestoreService.createPlayerRequest(request);
              },
              child: _isPublishing 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : Text("PUBLISH REQUEST", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
