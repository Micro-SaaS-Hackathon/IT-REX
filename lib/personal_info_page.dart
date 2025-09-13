import 'package:flutter/material.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  // Form controllers
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _allergiesController.dispose();
    _diseaseHistoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Personal Information'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            _buildTextField(
              controller: _nameController,
              label: 'Name',
              hint: 'Enter your name',
            ),
            const SizedBox(height: 16),

            // Surname Field
            _buildTextField(
              controller: _surnameController,
              label: 'Surname',
              hint: 'Enter your surname',
            ),
            const SizedBox(height: 16),

            // Allergies Field
            _buildTextField(
              controller: _allergiesController,
              label: 'Allergies',
              hint: 'List your allergies (if any)',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Disease History Field
            _buildTextField(
              controller: _diseaseHistoryController,
              label: 'Disease History',
              hint: 'Enter your medical history',
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePersonalInfo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Information',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          maxLines: maxLines,
        ),
      ],
    );
  }

  void _savePersonalInfo() {
    // TODO: Implement saving functionality
    // You can save this information to local storage or a database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personal information saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}