import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class AddEditClassScreen extends StatefulWidget {
  final UserModel? currentUser;
  final ClassModel? existingClass;

  const AddEditClassScreen({
    super.key,
    this.currentUser,
    this.existingClass,
  });

  @override
  State<AddEditClassScreen> createState() => _AddEditClassScreenState();
}

class _AddEditClassScreenState extends State<AddEditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool get _isEditing => widget.existingClass != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.existingClass!.name;
      _codeController.text = widget.existingClass!.code;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updated = ClassModel(
          id: widget.existingClass!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          createdBy: widget.existingClass!.createdBy,
          studentIds: widget.existingClass!.studentIds,
        );
        await _firestoreService.updateClass(updated);
      } else {
        final newClass = ClassModel(
          id: '',
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          createdBy: widget.currentUser?.uid ?? '',
          studentIds: const [],
        );
        await _firestoreService.addClass(newClass);
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
          _isEditing ? 'Edit Class' : 'Create Class',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g. BCNS24B Full Time',
                  prefixIcon: Icon(Icons.class_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter class name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Class Code',
                  hintText: 'e.g. CPMA',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter class code' : null,
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: _isEditing ? 'Update Class' : 'Create Class',
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