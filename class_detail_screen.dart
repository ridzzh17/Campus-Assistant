import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel? currentUser;

  const ClassDetailScreen({
    super.key,
    required this.classModel,
    this.currentUser,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<UserModel> _students = [];
  bool _loadingStudents = true;

  bool get _canEdit =>
      widget.currentUser?.role == 'lecturer' ||
      widget.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    final List<UserModel> students = [];

    for (final uid in widget.classModel.studentIds) {
      final user = await _firestoreService.getUser(uid);
      if (user != null) students.add(user);
    }

    setState(() {
      _students = students;
      _loadingStudents = false;
    });
  }

  Future<void> _addStudent() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Find user by email
      final user = await _firestoreService.getUserByEmail(email);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No user found with that email'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (user.role != 'student') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only students can be added to a class'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (widget.classModel.studentIds.contains(user.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student is already in this class'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Add student to class
      await _firestoreService.addStudentToClass(
          widget.classModel.id, user.uid);

      _emailController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} added to class'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }

      // Refresh student list
      await _loadStudents();
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

  Future<void> _removeStudent(UserModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Remove ${student.name} from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.removeStudentFromClass(
          widget.classModel.id, student.uid);
      await _loadStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} removed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.classModel.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class info card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        widget.classModel.code.isNotEmpty
                            ? widget.classModel.code[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.classModel.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        Text('Code: ${widget.classModel.code}',
                            style: const TextStyle(
                                color: AppColors.textLight)),
                        Text(
                            '${widget.classModel.studentIds.length} student(s)',
                            style: const TextStyle(
                                color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Add student section (only for lecturer/admin)
            if (_canEdit) ...[
              const Text(
                'Add Student by Email',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'student@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Students list
            const Text(
              'Enrolled Students',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 10),

            _loadingStudents
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Text(
                        'No students enrolled yet',
                        style: TextStyle(color: AppColors.textLight),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.secondary.withOpacity(0.1),
                                child: Text(
                                  student.name.isNotEmpty
                                      ? student.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(student.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(student.email,
                                  style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12)),
                              trailing: _canEdit
                                  ? IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _removeStudent(student),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}