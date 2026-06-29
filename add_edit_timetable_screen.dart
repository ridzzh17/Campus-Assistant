import 'package:flutter/material.dart';
import '../../models/timetable_model.dart';
import '../../models/user_model.dart';
import '../../models/class_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class AddEditTimetableScreen extends StatefulWidget {
  final UserModel? currentUser;
  final TimetableModel? existingItem;

  const AddEditTimetableScreen({
    super.key,
    this.currentUser,
    this.existingItem,
  });

  @override
  State<AddEditTimetableScreen> createState() =>
      _AddEditTimetableScreenState();
}

class _AddEditTimetableScreenState extends State<AddEditTimetableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _moduleController = TextEditingController();
  final _lecturerController = TextEditingController();
  final _roomController = TextEditingController();
  final _timeController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedDay = 'Monday';
  String? _selectedClassId;
  List<ClassModel> _classes = [];
  bool _isLoading = false;
  bool _loadingClasses = true;
  bool get _isEditing => widget.existingItem != null;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (_isEditing) {
      _moduleController.text = widget.existingItem!.module;
      _lecturerController.text = widget.existingItem!.lecturer;
      _roomController.text = widget.existingItem!.room;
      _timeController.text = widget.existingItem!.time;
      _selectedDay = widget.existingItem!.day;
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
    _moduleController.dispose();
    _lecturerController.dispose();
    _roomController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a class'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updated = TimetableModel(
          id: widget.existingItem!.id,
          module: _moduleController.text.trim(),
          lecturer: _lecturerController.text.trim(),
          room: _roomController.text.trim(),
          day: _selectedDay,
          time: _timeController.text.trim(),
          createdBy: widget.existingItem!.createdBy,
          classId: _selectedClassId!,
        );
        await _firestoreService.updateTimetable(updated);
      } else {
        final newItem = TimetableModel(
          id: '',
          module: _moduleController.text.trim(),
          lecturer: _lecturerController.text.trim(),
          room: _roomController.text.trim(),
          day: _selectedDay,
          time: _timeController.text.trim(),
          createdBy: widget.currentUser?.uid ?? '',
          classId: _selectedClassId!,
        );
        await _firestoreService.addTimetable(newItem);
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Entry' : 'Add Entry',
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

                        // Module
                        TextFormField(
                          controller: _moduleController,
                          decoration: const InputDecoration(
                            labelText: 'Module Name',
                            prefixIcon: Icon(Icons.book_outlined),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter module name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Lecturer
                        TextFormField(
                          controller: _lecturerController,
                          decoration: const InputDecoration(
                            labelText: 'Lecturer',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter lecturer name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Room
                        TextFormField(
                          controller: _roomController,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            prefixIcon: Icon(Icons.room_outlined),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter room number'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Day
                        DropdownButtonFormField<String>(
                          value: _selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Day',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          items: _days
                              .map((d) => DropdownMenuItem(
                                  value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedDay = v!),
                        ),
                        const SizedBox(height: 16),

                        // Time
                        TextFormField(
                          controller: _timeController,
                          readOnly: true,
                          onTap: _pickTime,
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Pick a time'
                              : null,
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: _isEditing
                              ? 'Update Entry'
                              : 'Add Entry',
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