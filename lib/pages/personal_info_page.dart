import 'package:flutter/material.dart';
import '../services/personal_info_service.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  // Form controllers
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _ageController = TextEditingController();
  final _sexController = TextEditingController();
  final _countryController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _diseaseHistoryController = TextEditingController();
  final PersonalInfoService _personalInfo = PersonalInfoService();

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _ageController.dispose();
    _sexController.dispose();
    _countryController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _diseaseHistoryController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalInfo() async {
    await _personalInfo.loadPersonalInfo();
    setState(() {
      _nameController.text = _personalInfo.name;
      _surnameController.text = _personalInfo.surname;
      _ageController.text = _personalInfo.age;
      _sexController.text = _personalInfo.sex;
      _countryController.text = _personalInfo.country;
      _heightController.text = _personalInfo.height;
      _weightController.text = _personalInfo.weight;
      _allergiesController.text = _personalInfo.allergies;
      _diseaseHistoryController.text = _personalInfo.diseaseHistory;
    });
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
            // Basic Information
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

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

            // Age Field
            _buildTextField(
              controller: _ageController,
              label: 'Age',
              hint: 'Enter your age',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Sex Field
            _buildTextField(
              controller: _sexController,
              label: 'Sex',
              hint: 'Enter your sex (e.g., Male, Female, Other)',
            ),
            const SizedBox(height: 16),

            // Country Field
            _buildTextField(
              controller: _countryController,
              label: 'Country',
              hint: 'Enter your country',
            ),
            const SizedBox(height: 16),

            // Physical Information
            Text(
              'Physical Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Height Field
            _buildTextField(
              controller: _heightController,
              label: 'Height',
              hint: 'Enter your height (cm)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Weight Field
            _buildTextField(
              controller: _weightController,
              label: 'Weight',
              hint: 'Enter your weight (kg)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Medical Information
            Text(
              'Medical Information',
              style: Theme.of(context).textTheme.titleLarge,
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
              label: 'Disease History and Genetic Diseases',
              hint: 'Enter your medical history and any genetic conditions',
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
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Future<void> _savePersonalInfo() async {
    await _personalInfo.savePersonalInfo(
      name: _nameController.text,
      surname: _surnameController.text,
      age: _ageController.text,
      sex: _sexController.text,
      country: _countryController.text,
      height: _heightController.text,
      weight: _weightController.text,
      allergies: _allergiesController.text,
      diseaseHistory: _diseaseHistoryController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal information saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}