import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/announcement_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class AddEditAnnouncementScreen extends StatefulWidget {
  final UserModel? currentUser;
  final AnnouncementModel? existingItem;

  const AddEditAnnouncementScreen({
    super.key,
    this.currentUser,
    this.existingItem,
  });

  @override
  State<AddEditAnnouncementScreen> createState() =>
      _AddEditAnnouncementScreenState();
}

class _AddEditAnnouncementScreenState
    extends State<AddEditAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String _existingImageUrl = '';
  String? _selectedClassId;
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  bool _loadingClasses = true;
  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (_isEditing) {
      _titleController.text = widget.existingItem!.title;
      _bodyController.text = widget.existingItem!.body;
      _existingImageUrl = widget.existingItem!.imageUrl;
      _selectedClassId = widget.existingItem!.classId;
    }
  }

  Future<void> _loadClasses() async {
    final uid = widget.currentUser?.uid ?? '';
    final role = widget.currentUser?.role ?? '';

    Stream<List<ClassModel>> stream;
    if (role == 'admin') {
      stream = _firestoreService.getClasses();
    } else {
      stream = _firestoreService.getClassesForLecturer(uid);
    }

    stream.first.then((classes) {
      setState(() {
        _classes = classes;
        _loadingClasses = false;
        // Default to 'general' selected
        _selectedClassId ??= 'general';
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadImage(
          _selectedImage!,
          'announcements',
        );
      }

      if (_isEditing) {
        final updated = AnnouncementModel(
          id: widget.existingItem!.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          author: widget.existingItem!.author,
          imageUrl: imageUrl,
          timestamp: widget.existingItem!.timestamp,
          classId: _selectedClassId ?? 'general',
        );
        await _firestoreService.updateAnnouncement(updated);
      } else {
        final newItem = AnnouncementModel(
          id: '',
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          author: widget.currentUser?.name ?? 'Unknown',
          imageUrl: imageUrl,
          timestamp: DateTime.now(),
          classId: _selectedClassId ?? 'general',
        );
        await _firestoreService.addAnnouncement(newItem);

        // Trigger push notification
        await NotificationService().showLocalNotification(
          title: '📢 New Announcement',
          body: _titleController.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Announcement' : 'New Announcement',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target dropdown — General or specific class
                    DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Post To',
                        prefixIcon: Icon(Icons.group_outlined),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'general',
                          child: Text('📢 General (Everyone)'),
                        ),
                        ..._classes.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('🏫 ${c.name}'),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedClassId = v),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: 16),

                    // Body
                    TextFormField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        prefixIcon: Icon(Icons.message_outlined),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Enter a message'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Image
                    const Text('Attach Image (optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    const SizedBox(height: 10),

                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      )
                    else if (_existingImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_existingImageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      )
                    else
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.textLight),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[100],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 40, color: AppColors.textLight),
                              SizedBox(height: 8),
                              Text('Tap to add image',
                                  style: TextStyle(
                                      color: AppColors.textLight)),
                            ],
                          ),
                        ),
                      ),

                    if (_selectedImage != null ||
                        _existingImageUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: _showImageSourceDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Change Image'),
                      ),

                    const SizedBox(height: 32),

                    CustomButton(
                      text:
                          _isEditing ? 'Update' : 'Post Announcement',
                      onPressed: _save,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}