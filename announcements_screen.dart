import 'package:flutter/material.dart';
import '../../models/announcement_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'add_edit_announcement_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  final UserModel? currentUser;
  const AnnouncementsScreen({super.key, this.currentUser});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool get _canEdit =>
      widget.currentUser?.role == 'lecturer' ||
      widget.currentUser?.role == 'admin';

  // Get the correct stream based on role
  Stream<List<AnnouncementModel>> get _announcementStream {
    final uid = widget.currentUser?.uid ?? '';
    final role = widget.currentUser?.role ?? '';
    final classIds = widget.currentUser?.classIds ?? [];

    if (role == 'student') {
      // Student sees general + their class announcements
      return _firestoreService.getAnnouncementsForStudent(classIds);
    } else {
      // Lecturer/Admin sees all announcements they can manage
      // For simplicity show general announcements by default
      return _firestoreService.getAnnouncementsForStudent(classIds);
    }
  }

  Future<void> _delete(AnnouncementModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteAnnouncement(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted')),
        );
      }
    }
  }

  // Badge color for general vs class announcements
  Color _badgeColor(String classId) {
    return classId == 'general' ? AppColors.secondary : AppColors.primary;
  }

  String _badgeLabel(String classId, List<ClassModel> classes) {
    if (classId == 'general') return 'General';
    try {
      return classes.firstWhere((c) => c.id == classId).code;
    } catch (_) {
      return 'Class';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditAnnouncementScreen(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: StreamBuilder<List<ClassModel>>(
        stream: _firestoreService.getClasses(),
        builder: (context, classSnapshot) {
          final classes = classSnapshot.data ?? [];

          return StreamBuilder<List<AnnouncementModel>>(
            stream: _announcementStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined,
                          size: 64, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      const Text('No announcements yet',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 16)),
                      if (_canEdit)
                        const Text('Tap + to post one',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _AnnouncementCard(
                    item: item,
                    canEdit: _canEdit,
                    badgeLabel: _badgeLabel(item.classId, classes),
                    badgeColor: _badgeColor(item.classId),
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditAnnouncementScreen(
                            currentUser: widget.currentUser,
                            existingItem: item,
                          ),
                        ),
                      );
                    },
                    onDelete: () => _delete(item),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Announcement Card ───────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel item;
  final bool canEdit;
  final String badgeLabel;
  final Color badgeColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.item,
    required this.canEdit,
    required this.badgeLabel,
    required this.badgeColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if exists)
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                item.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + badge + menu
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    // Class badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (canEdit)
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') onEdit();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Body
                Text(
                  item.body,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 14),
                ),
                const SizedBox(height: 10),

                // Author + timestamp
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(item.author,
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
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
}