import 'package:flutter/material.dart';
import '../../models/resource_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import 'add_edit_resource_screen.dart';
import 'resource_detail_screen.dart';

class ResourcesScreen extends StatefulWidget {
  final UserModel? currentUser;
  const ResourcesScreen({super.key, this.currentUser});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool get _canEdit =>
      widget.currentUser?.role == 'lecturer' ||
      widget.currentUser?.role == 'admin';

  Stream<List<ResourceModel>> get _resourceStream {
    final role = widget.currentUser?.role ?? '';
    final classIds = widget.currentUser?.classIds ?? [];

    if (role == 'student') {
      return _firestoreService.getResourcesForStudent(classIds);
    } else {
      if (classIds.isEmpty) return Stream.value([]);
      return _firestoreService.getResourcesForStudent(classIds);
    }
  }

  Future<void> _delete(ResourceModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resource'),
        content:
            const Text('Are you sure you want to delete this resource?'),
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
      await _firestoreService.deleteResource(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resource deleted')),
        );
      }
    }
  }

  IconData _getFileIcon(String url) {
    if (url.contains('.pdf')) return Icons.picture_as_pdf;
    if (url.contains('.doc') || url.contains('.docx'))
      return Icons.description;
    if (url.contains('.ppt') || url.contains('.pptx'))
      return Icons.slideshow;
    if (url.contains('.xls') || url.contains('.xlsx'))
      return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String url) {
    if (url.contains('.pdf')) return Colors.red;
    if (url.contains('.doc') || url.contains('.docx')) return Colors.blue;
    if (url.contains('.ppt') || url.contains('.pptx'))
      return Colors.orange;
    if (url.contains('.xls') || url.contains('.xlsx')) return Colors.green;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resources',
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
                    builder: (_) => AddEditResourceScreen(
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

          return StreamBuilder<List<ResourceModel>>(
            stream: _resourceStream,
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
                      Icon(Icons.folder_outlined,
                          size: 64, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      const Text('No resources yet',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 16)),
                      if (_canEdit)
                        const Text('Tap + to upload one',
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

                  // Get class name
                  String className = '';
                  try {
                    className = classes
                        .firstWhere((c) => c.id == item.classId)
                        .name;
                  } catch (_) {
                    className = '';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor:
                            _getFileColor(item.fileUrl).withOpacity(0.1),
                        child: Icon(
                          _getFileIcon(item.fileUrl),
                          color: _getFileColor(item.fileUrl),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark),
                            ),
                          ),
                          if (className.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                className,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textLight)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.person,
                                size: 12, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(item.uploadedBy,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight)),
                          ]),
                        ],
                      ),
                      trailing: _canEdit
                          ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditResourceScreen(
                                        currentUser: widget.currentUser,
                                        existingItem: item,
                                      ),
                                    ),
                                  );
                                }
                                if (v == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style:
                                          TextStyle(color: Colors.red)),
                                ),
                              ],
                            )
                          : const Icon(Icons.chevron_right,
                              color: AppColors.textLight),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ResourceDetailScreen(resource: item),
                          ),
                        );
                      },
                    ),
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