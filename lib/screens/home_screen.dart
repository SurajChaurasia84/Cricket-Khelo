import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/invite_model.dart';
import '../models/chat_model.dart';
import '../models/request_model.dart';
import '../models/player_request_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/invite_form.dart';
import '../widgets/player_request_form.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Position? _currentPosition;
  String _currentAddress = "Detecting location...";
  String? _locationError;
  final User? _user = FirebaseAuth.instance.currentUser;
  DateTime? _lastPressedAt;

  final Color _navyDark = Color(0xFF0A192F);
  final Color _navyMedium = Color(0xFF172A45);
  final Color _navyAccent = Color(0xFF30475E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Update PopScope canPop state
      }
    });
    
    // Trigger Daily Midnight Reset (only after user is logged in)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FirestoreService>(context, listen: false).checkAndPerformReset();
    });

    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _locationError = null;
      _currentPosition = null;
    });

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationError = "Turn on GPS to see nearby matches.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationError = "Location permission denied.");
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationError = "Location permissions are permanently denied.");
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationError = null;
        });
        _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = "Could not get location. Is your GPS on?");
      }
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (mounted && placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.subLocality ?? place.locality ?? 'Nearby'}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentAddress = "Location Pin Set");
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _showChatSheet(String matchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchChatSheet(matchId: matchId),
    );
  }

  void _showDeleteConfirmation(BuildContext context, FirestoreService firestore, String inviteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Match?", style: TextStyle(fontWeight: FontWeight.w900, color: _navyDark)),
        content: Text("Are you sure you want to cancel and delete this match invite? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await firestore.deleteInvite(inviteId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Match Invite Deleted"),
                  backgroundColor: Colors.red[700],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteRequestConfirmation(BuildContext context, FirestoreService firestore, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Request?", style: TextStyle(fontWeight: FontWeight.w900, color: _navyDark)),
        content: Text("Are you sure you want to remove your availability post?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await firestore.deletePlayerRequest(requestId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Availability Post Deleted"),
                  backgroundColor: Colors.red[700],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("DELETE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _showManageRequestsSheet(String matchId, FirestoreService firestore, {String title = "JOIN REQUESTS"}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navyDark),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<RequestModel>>(
                stream: firestore.getRequestsForMatch(matchId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text("No requests yet."));
                  }

                  final requests = snapshot.data!;
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.grey[50],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blueGrey[100],
                            backgroundImage: req.requesterPhoto != null ? CachedNetworkImageProvider(req.requesterPhoto!) : null,
                            child: req.requesterPhoto == null ? Icon(Icons.person, color: Colors.blueGrey) : null,
                          ),
                          title: Text(req.requesterName, style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Status: ${req.status.toUpperCase()}", 
                            style: TextStyle(
                              color: req.status == 'accepted' ? Colors.green : 
                                     req.status == 'rejected' ? Colors.red : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          trailing: req.status == 'pending' 
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => firestore.updateRequestStatus(req.requestId, 'accepted'),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => firestore.updateRequestStatus(req.requestId, 'rejected'),
                                  ),
                                ],
                              )
                            : Icon(
                                req.status == 'accepted' ? Icons.verified : Icons.block,
                                color: req.status == 'accepted' ? Colors.green : Colors.red,
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
      ),
    );
  }

  void _showActionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  width: 50,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                TabBar(
                  labelColor: _navyDark,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _navyDark,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(icon: Icon(Icons.person_add_rounded), text: "Invite"),
                    Tab(icon: Icon(Icons.sports_cricket_rounded), text: "Request"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: InviteForm(
                          lat: _currentPosition?.latitude,
                          lng: _currentPosition?.longitude,
                          ageGroup: _tabController.index == 0 ? "Under20" : "20+",
                        ),
                      ),
                      SingleChildScrollView(
                        child: PlayerRequestForm(
                          lat: _currentPosition?.latitude,
                          lng: _currentPosition?.longitude,
                          ageGroup: _tabController.index == 0 ? "Under20" : "20+",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteList(String ageGroup, FirestoreService firestore) {
    if (_locationError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _locationError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _navyDark, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _determinePosition,
              icon: Icon(Icons.refresh),
              label: Text("Retry Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navyDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _navyDark),
            SizedBox(height: 16),
            Text("Searching nearby...", style: TextStyle(color: _navyDark, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return StreamBuilder<List<InviteModel>>(
      stream: firestore.getInvites(ageGroup),
      builder: (context, inviteSnapshot) {
        return StreamBuilder<List<PlayerRequestModel>>(
          stream: firestore.getPlayerRequests(ageGroup),
          builder: (context, playerSnapshot) {
            if (inviteSnapshot.connectionState == ConnectionState.waiting || 
                playerSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: _navyDark));
            }

            final invites = inviteSnapshot.data ?? [];
            final playerRequests = playerSnapshot.data ?? [];

            List<dynamic> combinedList = [...invites, ...playerRequests];
            combinedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            combinedList = combinedList.where((item) {
              double distance = _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                item.lat,
                item.lng,
              );
              return distance <= 10.0;
            }).toList();

            if (combinedList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_cricket, size: 64, color: _navyAccent.withOpacity(0.5)),
                    SizedBox(height: 16),
                    Text(
                      "No activity in your area for $ageGroup.",
                      style: TextStyle(color: _navyDark, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _determinePosition,
              color: _navyDark,
              child: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: combinedList.length,
                itemBuilder: (context, index) {
                  final item = combinedList[index];
                  if (item is InviteModel) {
                    return _buildInviteCard(item, firestore);
                  } else {
                    return _buildPlayerRequestCard(item as PlayerRequestModel);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardHeader(String text, String time, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(InviteModel invite, FirestoreService firestore) {
    final bool isMyInvite = invite.createdBy == _user?.uid;
    final String formattedTime = DateFormat('hh:mm a').format(invite.timestamp);
    
    // Calculate distance
    String distanceStr = "Nearby";
    if (_currentPosition != null) {
      double dist = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        invite.lat,
        invite.lng,
      );
      distanceStr = "${dist.toStringAsFixed(1)} km away";
    }

    return Card(
      elevation: isMyInvite ? 8 : 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMyInvite ? BorderSide(color: _navyDark, width: 2) : BorderSide.none,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("INVITE", formattedTime, _navyDark),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _navyDark,
                            backgroundImage: invite.creatorPhoto != null ? CachedNetworkImageProvider(invite.creatorPhoto!) : null,
                            child: invite.creatorPhoto == null ? Icon(Icons.person, color: Colors.white, size: 20) : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.creatorName,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _navyDark),
                                ),
                                Text(
                                  distanceStr,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMyInvite)
                      PopupMenuButton<String>(
                        onSelected: (val) => _showDeleteConfirmation(context, firestore, invite.inviteId),
                        itemBuilder: (context) => [PopupMenuItem(value: 'delete', child: Text("Delete Match"))],
                        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  "Players Needed: ${invite.playersRequired}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _navyMedium),
                ),
                if (invite.message.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(invite.message, style: TextStyle(color: Colors.black87, fontSize: 14)),
                  ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(child: Text(invite.address, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1)),
                  ],
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showChatSheet(invite.inviteId),
                      icon: Icon(Icons.forum_outlined, size: 20),
                      label: Text("Discuss"),
                      style: TextButton.styleFrom(foregroundColor: _navyDark),
                    ),
                    if (!isMyInvite)
                      ElevatedButton(
                        onPressed: () async {
                          final req = RequestModel(
                            requestId: '',
                            matchId: invite.inviteId,
                            requesterId: _user!.uid,
                            requesterName: _user!.displayName ?? "Player",
                            requesterPhoto: _user!.photoURL,
                            status: 'pending',
                            timestamp: DateTime.now(),
                          );
                          await firestore.sendJoinRequest(req);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent!")));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _navyDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text("Join Match"),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => _showManageRequestsSheet(invite.inviteId, firestore),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: _navyDark, elevation: 0),
                        child: Text("Manage"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRequestCard(PlayerRequestModel req) {
    final bool isMe = req.playerId == _user?.uid;
    final String formattedTime = DateFormat('hh:mm a').format(req.timestamp);

    // Calculate distance
    String distanceStr = "Nearby";
    if (_currentPosition != null) {
      double dist = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        req.lat,
        req.lng,
      );
      distanceStr = "${dist.toStringAsFixed(1)} km away";
    }

    return Card(
      elevation: isMe ? 8 : 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe ? BorderSide(color: _navyAccent, width: 2) : BorderSide.none,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("REQUEST", formattedTime, _navyAccent),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blueGrey[100],
                            backgroundImage: req.playerPhoto != null ? CachedNetworkImageProvider(req.playerPhoto!) : null,
                            child: req.playerPhoto == null ? Icon(Icons.person, color: Colors.blueGrey, size: 20) : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.playerName,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _navyDark),
                                ),
                                Text(
                                  distanceStr,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMe)
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          final firestore = Provider.of<FirestoreService>(context, listen: false);
                          _showDeleteRequestConfirmation(context, firestore, req.requestId);
                        },
                        itemBuilder: (context) => [PopupMenuItem(value: 'delete', child: Text("Delete Request"))],
                        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  "Players Available: ${req.playersAvailable}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _navyMedium),
                ),
                if (req.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      req.message,
                      style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        req.address,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showChatSheet(req.requestId),
                      icon: Icon(Icons.forum_outlined, size: 20),
                      label: Text("Discuss"),
                      style: TextButton.styleFrom(foregroundColor: _navyDark),
                    ),
                    if (!isMe)
                      ElevatedButton(
                        onPressed: () async {
                          final firestore = Provider.of<FirestoreService>(context, listen: false);
                          final r = RequestModel(
                            requestId: '',
                            matchId: req.requestId,
                            requesterId: _user!.uid,
                            requesterName: _user!.displayName ?? "Captain",
                            requesterPhoto: _user!.photoURL,
                            status: 'pending',
                            timestamp: DateTime.now(),
                          );
                          await firestore.sendJoinRequest(r);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invite sent to player!")));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navyDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text("Invite to Match"),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          final firestore = Provider.of<FirestoreService>(context, listen: false);
                          _showManageRequestsSheet(req.requestId, firestore, title: "INVITES RECEIVED");
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: _navyDark, elevation: 0),
                        child: Text("Manage"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
        } else {
          final now = DateTime.now();
          if (_lastPressedAt == null || 
              now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
            _lastPressedAt = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Tap again to exit", textAlign: TextAlign.center),
                duration: const Duration(seconds: 2),
                backgroundColor: _navyDark.withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                width: 180,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CRICKET KHELO",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 18),
            ),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.white70),
                SizedBox(width: 4),
                Text(_currentAddress, style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: _navyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              backgroundImage: _user?.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
              child: _user?.photoURL == null ? Icon(Icons.person, size: 16, color: Colors.white) : null,
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(location: _currentAddress))),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _navyMedium, borderRadius: BorderRadius.circular(30)),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [Tab(text: "Under 20"), Tab(text: "Above 20")],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInviteList("Under20", firestoreService),
          _buildInviteList("20+", firestoreService),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showActionBottomSheet,
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: _navyDark,
        elevation: 6,
      ),
    ),
  );
}
}

class MatchChatSheet extends StatefulWidget {
  final String matchId;
  MatchChatSheet({required this.matchId});

  @override
  _MatchChatSheetState createState() => _MatchChatSheetState();
}

class _MatchChatSheetState extends State<MatchChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;
  late Stream<DatabaseEvent> _chatStream;

  @override
  void initState() {
    super.initState();
    final chatRef = _dbRef.child('chats').child(widget.matchId);
    chatRef.keepSynced(true); // Keep data ready in background for instant load
    _chatStream = chatRef.onValue;
  }

  void _sendMessage() {
    if (_controller.text.isEmpty || _user == null) return;

    final message = ChatMessage(
      senderId: _user!.uid,
      senderName: _user!.displayName ?? "Player",
      senderPhoto: _user!.photoURL,
      text: _controller.text,
      timestamp: DateTime.now(),
    );

    _dbRef.child('chats').child(widget.matchId).push().set(message.toMap());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(margin: EdgeInsets.symmetric(vertical: 10), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Match Discussion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A192F))),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return Center(child: Text("Start the discussion!"));
                Map<dynamic, dynamic> values = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<ChatMessage> messages = values.values.map((v) => ChatMessage.fromMap(v)).toList();
                messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg.senderId == _user?.uid;
                    bool showHeader = true;
                    if (index < messages.length - 1) {
                      final nextMsg = messages[index + 1];
                      if (nextMsg.senderId == msg.senderId) showHeader = false;
                    }

                    return Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe && showHeader) ...[
                          SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(radius: 12, backgroundImage: msg.senderPhoto != null ? NetworkImage(msg.senderPhoto!) : null, child: msg.senderPhoto == null ? Icon(Icons.person, size: 12) : null),
                              SizedBox(width: 8),
                              Text(msg.senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            ],
                          ),
                          SizedBox(height: 4),
                        ],
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 2),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Color(0xFF0A192F) : Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(12).copyWith(bottomRight: isMe ? Radius.zero : Radius.circular(12), bottomLeft: !isMe ? Radius.zero : Radius.circular(12)),
                            ),
                            child: Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: "Type your message...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)))),
                SizedBox(width: 8),
                CircleAvatar(backgroundColor: Color(0xFF0A192F), child: IconButton(icon: Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
