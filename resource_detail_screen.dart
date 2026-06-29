import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/resource_model.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class ResourceDetailScreen extends StatelessWidget {
  final ResourceModel resource;
  const ResourceDetailScreen({super.key, required this.resource});

Future<void> _openFile(BuildContext context) async {
  // Use Google Docs viewer to open any file in browser
  final googleDocsUrl =
      'https://docs.google.com/viewer?url=${Uri.encodeComponent(resource.fileUrl)}';
  final uri = Uri.parse(googleDocsUrl);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resource Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File icon
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.insert_drive_file,
                    size: 50, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(resource.title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),

            // Description
            Text(resource.description,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textLight)),
            const SizedBox(height: 24),

            // Meta info
            _MetaRow(icon: Icons.person, label: 'Uploaded by', value: resource.uploadedBy),
            _MetaRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value:
                  '${resource.timestamp.day}/${resource.timestamp.month}/${resource.timestamp.year}',
            ),
            const SizedBox(height: 40),

            // Open file button
            CustomButton(
  text: 'Open File',
  onPressed: () => _openFile(context),
),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: AppColors.textLight)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}