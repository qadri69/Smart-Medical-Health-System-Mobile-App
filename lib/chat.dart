import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Add this new NurseListPage class
class NurseListPage extends StatefulWidget {
  const NurseListPage({Key? key}) : super(key: key);

  @override
  _NurseListPageState createState() => _NurseListPageState();
}

class _NurseListPageState extends State<NurseListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _nurses = [];
  String? _errorMessage;

  List<Map<String, dynamic>> _filteredNurses = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNurses();
    _searchController.addListener(() {
      _filterNurses(_searchController.text);
    });
  }

  // Update the _loadNurses method to use Realtime Database
  Future<void> _loadNurses() async {
    try {
      print("Attempting to fetch nurses from Realtime Database...");

      // Reference to the 'nurse' path in your database
      final databaseReference = FirebaseDatabase.instance.ref().child('nurse');

      // Get the data snapshot
      final DatabaseEvent event = await databaseReference.once();

      // Check if data exists
      if (event.snapshot.value == null) {
        print("No data found at 'nurse' path");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print("Data retrieved successfully");

      // Convert the data to a usable format
      final Map<dynamic, dynamic> values =
          event.snapshot.value as Map<dynamic, dynamic>;

      print("Raw data: $values");

      setState(() {
        _nurses = values.entries
            .map((entry) {
              print("Processing entry: $entry");
              Map<dynamic, dynamic> nurseData =
                  entry.value as Map<dynamic, dynamic>;

              // Get the fname field
              String name = '';
              if (nurseData.containsKey('fname')) {
                name = nurseData['fname'].toString();
              } else if (nurseData.containsKey('name')) {
                name = nurseData['name'].toString();
              } else {
                print("No name field found for entry: $entry");
                return null;
              }

              return {
                'id': entry.key,
                'fname': name,
              };
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>()
            .toList();

        print("Processed ${_nurses.length} valid nurse records");
        _filteredNurses = List.from(_nurses);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading nurses: $e");
      setState(() {
        _errorMessage = 'Failed to load nurses: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterNurses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredNurses = List.from(_nurses);
      } else {
        _filteredNurses = _nurses
            .where((nurse) =>
                nurse['fname'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
            child: Text(_errorMessage!,
                style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search nurses',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _filteredNurses.isEmpty
                ? const Center(child: Text('No nurses available at the moment'))
                : ListView.builder(
                    itemCount: _filteredNurses.length,
                    itemBuilder: (context, index) {
                      final nurse = _filteredNurses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              nurse['fname'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          title: Text(
                            nurse['fname'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: const Text('Available for chat'),
                          trailing: const Icon(Icons.chat_bubble_outline,
                              color: Colors.blue),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  nurseId: nurse['id'],
                                  nurseName: nurse['fname'],
                                  userId:
                                      getCurrentUserId(), // You'll need to implement this function
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Add this function to get the current user ID
String getCurrentUserId() {
  // If using Firebase Auth:
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return user.uid;
  }
  // Fallback or for testing
  return 'test-user-id';
}

// Keep the existing ChatPage class
class ChatPage extends StatefulWidget {
  final String nurseId;
  final String nurseName;
  final String userId; // Add this parameter

  const ChatPage({
    Key? key,
    required this.nurseId,
    required this.nurseName,
    required this.userId, // Add this required parameter
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isNurseOnline = false;
  bool _isNurseTyping = false;

  // Reference to the chat messages in the database
  late DatabaseReference _chatRef;

  @override
  void initState() {
    super.initState();
    // Each chat is stored under a unique ID combining patient and nurse IDs
    // Using the actual userId instead of hardcoded value
    _chatRef = FirebaseDatabase.instance
        .ref()
        .child('chats')
        .child('${widget.userId}_${widget.nurseId}')
        .child('messages');

    _connectToChat();
    _loadPreviousMessages();
  }

  void _connectToChat() {
    // TODO: Implement connection to chat service/backend
    // This would connect to your backend service that handles
    // communication between the mobile app and web app

    // Simulating nurse coming online after 2 seconds
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _isNurseOnline = true;
      });
    });
  }

  void _loadPreviousMessages() async {
    try {
      final DatabaseEvent event = await _chatRef.once();

      if (event.snapshot.value != null) {
        final messagesData = event.snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _messages.clear();
          messagesData.forEach((key, value) {
            _messages.add(ChatMessage(
              text: value['text'],
              isFromNurse: value['isFromNurse'],
              timestamp:
                  DateTime.fromMillisecondsSinceEpoch(value['timestamp']),
            ));
          });

          // Sort messages by timestamp
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });

        // Scroll to bottom after loading messages
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (e) {
      print("Error loading messages: $e");
    }
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    if (text.trim().isEmpty) return;

    final newMessage = ChatMessage(
      text: text,
      isFromNurse: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(newMessage);
    });

    // Save message to Firebase
    _chatRef.push().set({
      'text': newMessage.text,
      'isFromNurse': newMessage.isFromNurse,
      'timestamp': newMessage.timestamp.millisecondsSinceEpoch,
    });

    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // TODO: Send message to backend/chat service

    // Simulate nurse typing and response for demo purposes
    setState(() {
      _isNurseTyping = true;
    });

    Timer(const Duration(seconds: 2), () {
      setState(() {
        _isNurseTyping = false;
        _messages.add(
          ChatMessage(
            text: "I've received your message. A nurse will respond shortly.",
            isFromNurse: true,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.nurseName),
            Text(
              _isNurseOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: _isNurseOnline ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageItem(_messages[index]);
              },
            ),
          ),
          if (_isNurseTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Nurse is typing...",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    return Align(
      alignment:
          message.isFromNurse ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: message.isFromNurse
              ? Colors.grey[300]
              : Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isFromNurse ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: message.isFromNurse ? Colors.black54 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.0),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }

  // Replace the _formatTime method with this _formatDateTime method
  String _formatDateTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    String dateStr;
    if (messageDate == today) {
      dateStr = 'Today';
    } else if (messageDate == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }

    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return '$dateStr, $timeStr';
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // TODO: Close any active connections to chat service
    super.dispose();
  }
}

// Model for chat messages
class ChatMessage {
  final String text;
  final bool isFromNurse;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isFromNurse,
    required this.timestamp,
  });
}
