import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/invite_model.dart';
import '../models/chat_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/invite_form.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Position? _currentPosition;

  final Color _navyDark = Color(0xFF0A192F);
  final Color _navyMedium = Color(0xFF172A45);
  final Color _navyAccent = Color(0xFF30475E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Location error: $e");
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

  Widget _buildInviteList(String ageGroup, FirestoreService firestore) {
    if (_currentPosition == null) {
      return Center(child: CircularProgressIndicator(color: _navyDark));
    }

    return StreamBuilder<List<InviteModel>>(
      stream: firestore.getInvites(ageGroup),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _navyDark));
        }

        final allInvites = snapshot.data ?? [];
        final nearbyInvites = allInvites.where((invite) {
          double distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            invite.lat,
            invite.lng,
          );
          return distance <= 5.0;
        }).toList();

        if (nearbyInvites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_cricket, size: 64, color: _navyAccent.withOpacity(0.5)),
                SizedBox(height: 16),
                Text(
                  "No nearby invites for $ageGroup.",
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
            itemCount: nearbyInvites.length,
            itemBuilder: (context, index) {
              final invite = nearbyInvites[index];
              double distance = _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                invite.lat,
                invite.lng,
              );

              return Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _navyDark,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Match Invite",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 18, 
                                      color: _navyDark
                                    ),
                                  ),
                                  Text(
                                    "${distance.toStringAsFixed(1)} km away",
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('hh:mm a').format(invite.timestamp),
                            style: TextStyle(color: _navyMedium, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Players Needed: ${invite.playersRequired}",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navyMedium),
                      ),
                      if (invite.message.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          invite.message,
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showChatSheet(invite.inviteId),
                            icon: Icon(Icons.chat_bubble_outline, size: 20),
                            label: Text("Match Discussion"),
                            style: TextButton.styleFrom(
                              foregroundColor: _navyDark,
                              padding: EdgeInsets.symmetric(horizontal: 0),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Request sent!")),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navyDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text("Request to Join"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          "CRICKET KHELO",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 22,
          ),
        ),
        backgroundColor: _navyDark,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text("Logout"),
                onTap: () => authService.signOut(),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _navyMedium,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              labelColor: _navyDark,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: [
                Tab(text: "Under 20"),
                Tab(text: "20+"),
              ],
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.extended(
              heroTag: "request_btn",
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("My Requests feature coming soon!")),
                );
              },
              label: Text("My Requests"),
              icon: Icon(Icons.history),
              backgroundColor: _navyAccent,
              foregroundColor: Colors.white,
            ),
            FloatingActionButton.extended(
              heroTag: "invite_btn",
              onPressed: () {
                if (_currentPosition == null) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => InviteForm(
                    lat: _currentPosition!.latitude,
                    lng: _currentPosition!.longitude,
                    ageGroup: _tabController.index == 0 ? "Under20" : "20+",
                  ),
                );
              },
              label: Text("Invite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              icon: Icon(Icons.add, color: Colors.white),
              backgroundColor: _navyDark,
            ),
          ],
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

  void _sendMessage() {
    if (_controller.text.isEmpty || _user == null) return;

    final message = ChatMessage(
      senderId: _user!.uid,
      senderName: _user!.displayName ?? "Player",
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Match Discussion",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A192F)),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.child('chats').child(widget.matchId).onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return Center(child: Text("Start the discussion!"));
                }

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

                    return Align(
                      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Color(0xFF0A192F) : Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12).copyWith(
                            bottomLeft: isMe ? Radius.zero : Radius.circular(12),
                            bottomRight: !isMe ? Radius.zero : Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              Text(
                                msg.senderName,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              ),
                            Text(
                              msg.text,
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Color(0xFF0A192F),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
