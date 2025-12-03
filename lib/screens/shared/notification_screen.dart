import 'package:elearning_management_app/models/notification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  final UserModel user;

  const NotificationScreen({super.key, required this.user});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 1. Add state variables for filtering
  final TextEditingController _searchController = TextEditingController();
  bool _showUnreadOnly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return Icons.announcement;
      case NotificationType.deadline:
        return Icons.event;
      case NotificationType.feedback:
        return Icons.event_note;
      case NotificationType.submission:
        return Icons.event_available;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return Colors.blue;
      case NotificationType.deadline:
        return Colors.red;
      case NotificationType.feedback:
        return Colors.teal;
      case NotificationType.submission:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<NotificationProvider>().markAllAsRead(
                    widget.user.id,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                  ),
                );
              }
            },
            child: const Text(
              'Mark all read',
              // Ensure text is visible depending on your AppBar theme;
              // typically AppBar actions are white on dark backgrounds or black on light.
              // style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 2. Add Filter and Search Controls Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notifications...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Unread Filter Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Show unread only',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _showUnreadOnly,
                      onChanged: (value) {
                        setState(() {
                          _showUnreadOnly = value;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Notification List
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 4. Apply Filtering Logic Here
                final filteredList = provider.notifications.where((n) {
                  // Check Unread Status
                  if (_showUnreadOnly && n.isRead) {
                    return false;
                  }

                  // Check Search Query (Title or Message)
                  if (_searchQuery.isNotEmpty) {
                    final titleMatch =
                        n.title.toLowerCase().contains(_searchQuery);
                    final msgMatch =
                        n.message.toLowerCase().contains(_searchQuery);
                    if (!titleMatch && !msgMatch) {
                      return false;
                    }
                  }

                  return true;
                }).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                // 5. Handle Empty States
                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.notifications_none,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No results found'
                              : (_showUnreadOnly
                                  ? 'No unread notifications'
                                  : 'No notifications'),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final notification = filteredList[index];
                    final isRead = notification.isRead;
                    final createdAt = notification.createdAt;

                    return Card(
                      elevation: isRead ? 1 : 3,
                      color: isRead ? Colors.white : Colors.blue[50],
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isRead
                            ? BorderSide.none
                            : BorderSide(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          if (!isRead) {
                            await provider.markAsRead(
                                notification.id, widget.user.id);
                          }
                          // Handle navigation logic here if needed
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Column
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _getNotificationColor(
                                  notification.type,
                                ).withOpacity(0.15),
                                child: Icon(
                                  _getNotificationIcon(notification.type),
                                  color:
                                      _getNotificationColor(notification.type),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Content Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification.title,
                                            style: GoogleFonts.poppins(
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.bold,
                                              fontSize: 14,
                                              color: isRead
                                                  ? Colors.black87
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.message,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat('MMM dd, HH:mm')
                                          .format(createdAt),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
