import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // Image variables
  File? _selectedImage;
  Uint8List? _imageBytes;
  
  // Voice variables
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _speechListening = false;
  String _wordsSpoken = '';
  double _confidenceLevel = 0;
  
  // AI response variables
  String _geminiResponse = 'Select an image or speak about your symptoms to get AI analysis.';
  bool _isLoading = false;
  
  // UI variables
  late TabController _tabController;
  int _currentTabIndex = 0;

  final ImagePicker _picker = ImagePicker();
  // Your actual Gemini API key
  final String _apiKey = 'AIzaSyB3fjEC32g-rQTk-v4tn_nlgrkNGbWtUoE';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
    _initializeSpeech();
    
    if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      _geminiResponse = 'Please set your API key in the code.';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Initialize speech to text
  void _initializeSpeech() async {
    // Request microphone permission
    await Permission.microphone.request();
    
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        setState(() {
          _speechListening = status == 'listening';
        });
      },
      onError: (error) {
        setState(() {
          _speechListening = false;
        });
      },
    );
    setState(() {});
  }

  // Start listening to speech
  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  // Stop listening to speech
  void _stopListening() async {
    await _speechToText.stop();
  }

  // Handle speech result
  void _onSpeechResult(result) {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;
    });
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
          // Use a conditional to only set the File object on non-web platforms
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

      // The enhanced prompt for image analysis
      const String enhancedPrompt = 
        'Examine this image carefully and provide a detailed analysis. '
        'If it appears to be related to health or medicine—such as showing symptoms, physical conditions, medications, medical devices, or diagnostic results—describe what you observe in clinical terms, explain possible general implications, and advise the user to consult a licensed healthcare professional for proper diagnosis and treatment. '
        'If the image is not medically related, provide a thorough description of all visual elements, including objects, people, setting, and other notable details, using precise and objective observations.';
      
      final content = [
        Content.multi([
          TextPart(enhancedPrompt),
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

  // Function to send voice input to Gemini API
  Future<void> _sendVoiceToGemini() async {
    if (_wordsSpoken.trim().isEmpty) {
      setState(() {
        _geminiResponse = 'No speech detected. Please try speaking again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _geminiResponse = 'Analyzing your symptoms...';
    });

    try {
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

      final content = [
        Content.text(
          'You are a helpful medical AI assistant. A patient has described their symptoms as follows: "${_wordsSpoken}"\n\n'
          'Please provide helpful information about what these symptoms might indicate, possible causes, and general advice. '
          'Always remind the user that this is not a substitute for professional medical diagnosis and they should consult with healthcare professionals for proper evaluation and treatment. '
          'Be empathetic and supportive in your response.'
        ),
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

  // Clear all data
  void _clearAll() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _wordsSpoken = '';
      _confidenceLevel = 0;
      _geminiResponse = 'Select an image or speak about your symptoms to get AI analysis.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Image Analysis'),
            Tab(icon: Icon(Icons.mic), text: 'Voice Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Image Analysis Tab
          _buildImageAnalysisTab(),
          // Voice Analysis Tab
          _buildVoiceAnalysisTab(),
        ],
      ),
    );
  }

  Widget _buildImageAnalysisTab() {
    return Padding(
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
                  // Use Image.memory for web and Image.file for non-web platforms
                  child: kIsWeb
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain,
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
                  onPressed: _isLoading ? null : _clearAll,
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
    );
  }

  Widget _buildVoiceAnalysisTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Speech status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _speechListening ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _speechListening ? Colors.red.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _speechListening ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: _speechListening ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _speechListening ? 'Listening...' : 
                  (_speechEnabled ? 'Tap to speak about your symptoms' : 'Speech not available'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (_confidenceLevel > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Confidence: ${(_confidenceLevel * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Spoken text display
          if (_wordsSpoken.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you said:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _wordsSpoken,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // AI Response
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Analysis:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoading
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Analyzing your symptoms...'),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Text(
                              _geminiResponse,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Control buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _speechEnabled && !_isLoading
                      ? (_speechListening ? _stopListening : _startListening)
                      : null,
                  icon: Icon(_speechListening ? Icons.mic_off : Icons.mic),
                  label: Text(_speechListening ? 'Stop Recording' : 'Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _speechListening ? Colors.red.shade100 : null,
                    foregroundColor: _speechListening ? Colors.red.shade700 : null,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_wordsSpoken.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendVoiceToGemini,
                  icon: const Icon(Icons.send),
                  label: const Text('Analyze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade700,
                    minimumSize: const Size(50, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _clearAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade700,
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
    );
  }
}