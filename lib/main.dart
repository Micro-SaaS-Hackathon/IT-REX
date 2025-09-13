import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MedScan'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // A variable to hold the selected image file (for mobile).
  File? _selectedImage;
  // A variable to hold image bytes for web compatibility
  Uint8List? _imageBytes;
  // A variable to hold the AI's response.
  String _geminiResponse = 'The AI result will appear here.';
  // A variable to track the loading state.
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  // Replace with your actual Gemini API key
  final String _apiKey = 'YOUR_API_KEY_HERE'; // Add your API key here

  @override
  void initState() {
    super.initState();
    if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      _geminiResponse = 'Please set your API key in the code.';
    }
  }

  // Function to pick an image from the gallery or camera.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Read image bytes for web compatibility
        final bytes = await image.readAsBytes();
        
        setState(() {
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
          _imageBytes = bytes;
          _geminiResponse = 'Analyzing image...';
          _isLoading = true;
        });
        _sendImageToGemini();
      }
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error picking image: $e';
        _isLoading = false;
      });
    }
  }

  // Function to send the image and prompt to the Gemini API.
  Future<void> _sendImageToGemini() async {
    if (_imageBytes == null) {
      setState(() {
        _geminiResponse = 'No image selected.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Using Gemini 2.5 Flash Lite model
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite', 
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 4096,
        ),
      );

      // Enhanced prompt for medical/general image analysis
      final content = [
        Content.multi([
          TextPart(
            'Analyze this image in detail. If it appears to be medical-related (like symptoms, conditions, medications, medical devices, etc.), provide helpful information about what you observe, but remind the user to consult healthcare professionals for proper diagnosis and treatment. If it\'s not medical-related, describe what you see in the image thoroughly.'
          ),
          DataPart('image/jpeg', _imageBytes!),
        ]),
      ];

      final response = await model.generateContent(content);

      setState(() {
        _geminiResponse = response.text ?? 'No response from the AI.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error: ${e.toString()}\n\nPlease check your API key and internet connection.';
        _isLoading = false;
      });
    }
  }

  // Function to show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Display the selected image.
            if (_imageBytes != null)
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                        ? Image.memory(
                            _imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : (_selectedImage != null 
                            ? Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              )
                            : Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                              )
                          ),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Please select an image to analyze',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Display the AI response.
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isLoading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing image with Gemini 2.5 Flash Lite...'),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _geminiResponse,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Select Image'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_imageBytes != null)
                  ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _selectedImage = null;
                        _imageBytes = null;
                        _geminiResponse = 'The AI result will appear here.';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade700,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.clear),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}