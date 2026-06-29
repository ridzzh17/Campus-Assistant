import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/resource_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class AddEditResourceScreen extends StatefulWidget {
  final UserModel? currentUser;
  final ResourceModel? existingItem;

  const AddEditResourceScreen({
    super.key,
    this.currentUser,
    this.existingItem,
  });

  @override
  State<AddEditResourceScreen> createState() =>
      _AddEditResourceScreenState();
}

class _AddEditResourceScreenState extends State<AddEditResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  File? _selectedFile;
  String _selectedFileName = '';
  String _existingFileUrl = '';
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
      _descriptionController.text = widget.existingItem!.description;
      _existingFileUrl = widget.existingItem!.fileUrl;
      _selectedFileName = _existingFileUrl.split('/').last;
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
        if (_selectedClassId == null && classes.isNotEmpty) {
          _selectedClassId = classes.first.id;
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'
      ],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null && _existingFileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file to upload'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fileUrl = _existingFileUrl;

      if (_selectedFile != null) {
        fileUrl = await _storageService.uploadFile(
          _selectedFile!,
          'resources',
        );
      }

      if (_isEditing) {
        final updated = ResourceModel(
          id: widget.existingItem!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          fileUrl: fileUrl,
          uploadedBy: widget.existingItem!.uploadedBy,
          timestamp: widget.existingItem!.timestamp,
          classId: _selectedClassId!,
        );
        await _firestoreService.updateResource(updated);
      } else {
        final newItem = ResourceModel(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          fileUrl: fileUrl,
          uploadedBy: widget.currentUser?.name ?? 'Unknown',
          timestamp: DateTime.now(),
          classId: _selectedClassId!,
        );
        await _firestoreService.addResource(newItem);
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
          _isEditing ? 'Edit Resource' : 'Upload Resource',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? const Center(
                  child: Text(
                    'No classes found.\nCreate a class first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textLight),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Class dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            prefixIcon: Icon(Icons.class_outlined),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          items: _classes
                              .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedClassId = v),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Resource Title',
                            prefixIcon: Icon(Icons.title),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter a title'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description_outlined),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter a description'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        // File picker
                        const Text('Attach File',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                        const SizedBox(height: 10),

                        GestureDetector(
                          onTap: _pickFile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedFileName.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.textLight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: _selectedFileName.isNotEmpty
                                  ? AppColors.primary.withOpacity(0.05)
                                  : Colors.grey[100],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedFileName.isNotEmpty
                                      ? Icons.check_circle
                                      : Icons.upload_file,
                                  color: _selectedFileName.isNotEmpty
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedFileName.isNotEmpty
                                        ? _selectedFileName
                                        : 'Tap to select file\n(PDF, Word, PPT, Excel)',
                                    style: TextStyle(
                                      color: _selectedFileName.isNotEmpty
                                          ? AppColors.textDark
                                          : AppColors.textLight,
                                    ),
                                  ),
                                ),
                                if (_selectedFileName.isNotEmpty)
                                  TextButton(
                                    onPressed: _pickFile,
                                    child: const Text('Change'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: _isEditing
                              ? 'Update Resource'
                              : 'Upload Resource',
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