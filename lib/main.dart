import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'loading_page.dart';
import 'pages/personal_info_page.dart';
import 'services/personal_info_service.dart';

// A simple model for our data.
class Task {
  final int? id;
  final String title;
  final bool isCompleted;

  Task({
    this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

// Database service to handle all local database operations.
class DatabaseService {
  // Use a singleton pattern to ensure only one instance of the database exists.
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'medscan_database.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            isCompleted INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // --- CRUD Operations ---

  // Insert a task into the database.
  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve all tasks from the database.
  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: 'id DESC', // Order by most recent first
    );
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  // Delete all tasks.
  Future<void> deleteAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  // Delete a single task by its ID.
  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

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
      home: const LoadingPage(),
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

  // AI variables
  String _geminiResponse = 'Select an image or speak about your symptoms to get AI analysis.';
  final PersonalInfoService _personalInfo = PersonalInfoService();

  // Voice variables
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _speechListening = false;
  String _wordsSpoken = '';
  double _confidenceLevel = 0;

  // Database variables
  final DatabaseService _dbService = DatabaseService();
  List<Task> _history = [];

  // New state variables for selection mode
  bool _isSelectionMode = false;
  final Set<int> _selectedTaskIds = {};

  // Separate loading states for each tab
  bool _isImageLoading = false;
  bool _isVoiceLoading = false;
  bool _isHistoryLoading = false;

  // UI variables
  late TabController _tabController;

  final ImagePicker _picker = ImagePicker();
  // Your actual Gemini API key
  final String _apiKey = 'AIzaSyB3fjEC32g-rQTk-v4tn_nlgrkNGbWtUoE';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // Reset selection mode when switching tabs
        _isSelectionMode = false;
        _selectedTaskIds.clear();
      });
      // Load history when the history tab is selected
      if (_tabController.index == 2) {
        _loadHistory();
      }
    });

    // Load personal information
    _personalInfo.loadPersonalInfo();

    _initializeSpeech();
    _loadHistory();

    if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      _geminiResponse = 'Please set your API key in the code.';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isHistoryLoading = true;
    });
    final history = await _dbService.getTasks();
    setState(() {
      _history = history;
      _isHistoryLoading = false;
    });
  }

  Future<void> _saveAnalysis(String analysis) async {
    if (analysis.isNotEmpty) {
      await _dbService.insertTask(Task(title: analysis));
      _loadHistory();
    }
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
          _isImageLoading = true;
        });
        _sendImageToGemini();
      }
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error picking image: $e';
        _isImageLoading = false;
      });
    }
  }

  // Function to send the image and prompt to the Gemini API.
  Future<void> _sendImageToGemini() async {
    if (_imageBytes == null) {
      setState(() {
        _geminiResponse = 'No image selected.';
        _isImageLoading = false;
      });
      return;
    }

    try {
      final model = google_ai.GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: google_ai.GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 4096,
        ),
      );

      // Get personal medical context
      final String personalContext = _personalInfo.getPersonalContext();

      // The enhanced prompt for image analysis
      final String enhancedPrompt =
          '${personalContext}Provide a patient-friendly analysis (maximum 300 words). Use personal context internally.\n\n'
          'Structure the response in these sections:\n\n'
          '1. What Looks Good (in simple terms):\n'
          '   - Normal findings\n'
          '   - Healthy signs\n\n'
          '2. Areas of Concern (explained simply):\n'
          '   - Things that need attention\n'
          '   - Changes to watch\n\n'
          '3. Prevention Tips:\n'
          '   - Lifestyle recommendations\n'
          '   - Diet and exercise advice\n'
          '   - Daily habits to maintain health\n'
          '   - Ways to avoid complications\n\n'
          '4. Next Steps:\n'
          '   - What to do next\n'
          '   - When to seek care\n'
          '   - Self-care measures\n\n'
          '2. Primary anatomical area - specific organ/body part involved\n'
          '3. Abnormal values/results - high blood sugar, elevated BP, abnormal heart rate\n'
          '4. Asymmetry - differences between left/right structures\n'
          '5. Color & skin changes - redness, pallor, cyanosis, bruising\n'
          '6. Swelling/edema - location, severity, symmetry\n'
          '7. Lesion characteristics - size, shape, color, margins\n'
          '8. Abnormal movement/posture - tremors, limping, guarding\n'
          '9. Pain/discomfort signs - facial expressions, protective gestures\n'
          '10. Medical devices - placement, misuse, complications\n'
          '11. Medications/topicals - visible misuse, contraindications\n'
          '12. Infection/inflammation - redness, pus, warmth, oozing\n'
          '13. Wounds/surgical sites - size, depth, healing status\n'
          '14. Diagnostic results - abnormal labs (high/low values), concerning scan findings\n'
          '15. Environmental risks - hygiene issues, exposure hazards\n'
          '16. Image quality issues - poor lighting, blur, incomplete views\n'
          '17. Duration assessment - acute symptoms vs chronic conditions\n'
          '18. Systemic implications - broader health impacts\n'
          '19. Risk assessment - immediate threats or progression\n'
          '20. Recommended actions - urgency for consultation\n\n'
          'When mentioning medications:\n'
          '- Explain in simple terms what they do\n'
          '- List main side effects to watch for\n'
          '- Mention who should be careful with this medication\n\n'
          'Medical Terms Guide:\n'
          '- Include a simple explanation for any medical terms used\n'
          '- Use everyday language where possible\n\n'
          'Long-term Health Tips:\n'
          '- Suggest preventive screenings\n'
          '- Recommend healthy lifestyle changes\n'
          '- Include early warning signs to watch for\n'
          '- Mention risk factors to avoid\n\n'
          'For non-medical content:\n'
          'Provide objective description (objects, setting, features)\n\n'
          'IMPORTANT: This is general advice only, not a diagnosis.\n'
          'Please consult a licensed healthcare professional for proper evaluation.';

      final content = [
        google_ai.Content.multi([
          google_ai.TextPart(enhancedPrompt),
          google_ai.DataPart('image/jpeg', _imageBytes!),
        ]),
      ];

      final response = await model.generateContent(content);

      setState(() {
        _geminiResponse = response.text ?? 'No response from the AI.';
        _isImageLoading = false;
      });

      // Save the analysis to the database
      if (response.text != null) {
        _saveAnalysis(response.text!);
      }
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error: ${e.toString()}\n\nPlease check your API key and internet connection.';
        _isImageLoading = false;
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
      _isVoiceLoading = true;
      _geminiResponse = 'Analyzing your symptoms...';
    });

    try {
      final model = google_ai.GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: google_ai.GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 4096,
        ),
      );

      // Get personal medical context
      final String personalContext = _personalInfo.getPersonalContext();

      final content = [
        google_ai.Content.text(
            'You are a helpful medical AI assistant. A patient has described their symptoms as follows: "${_wordsSpoken}"\n\n'
            '${personalContext}'
            'Please provide helpful information about what these symptoms might indicate, possible causes, and general advice, '
            'taking into account any allergies or medical history provided above. '
            'Always remind the user that this is not a substitute for professional medical diagnosis and they should consult with healthcare professionals for proper evaluation and treatment. '
            'Be empathetic and supportive in your response.'),
      ];

      final response = await model.generateContent(content);

      setState(() {
        _geminiResponse = response.text ?? 'No response from the AI.';
        _isVoiceLoading = false;
      });

      // Save the analysis to the database
      if (response.text != null) {
        _saveAnalysis(response.text!);
      }
    } catch (e) {
      setState(() {
        _geminiResponse = 'Error: ${e.toString()}\n\nPlease check your API key and internet connection.';
        _isVoiceLoading = false;
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
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
    // Clear history from the database
    _dbService.deleteAllTasks().then((_) {
      _loadHistory();
    });
  }

  // Function to delete a single analysis entry.
  Future<void> _deleteTask(int id) async {
    await _dbService.deleteTask(id);
    _loadHistory();
  }

  // Function to delete selected tasks.
  Future<void> _deleteSelectedTasks() async {
    setState(() {
      _isHistoryLoading = true;
    });
    for (int id in _selectedTaskIds) {
      await _dbService.deleteTask(id);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
      _isHistoryLoading = false;
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            Image.asset(
              'assets/images/medscan.png',
              width: 30,  // Small icon size
              height: 30,
            ),
            const SizedBox(width: 8),  // Space between icon and text
            Text(widget.title),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalInfoPage(),
                ),
              );
            },
            tooltip: 'Personal Information',
          ),
        ],
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Image Analysis'),
            Tab(icon: Icon(Icons.mic), text: 'Voice Analysis'),
            Tab(icon: Icon(Icons.history), text: 'History'),
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
          // History Tab
          _buildHistoryTab(),
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
              child: _isImageLoading
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
                  onPressed: _isImageLoading ? null : _showImageSourceDialog,
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
                  onPressed: _isImageLoading ? null : _clearAll,
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
                  _speechListening ? 'Listening...' : (_speechEnabled ? 'Tap to speak about your symptoms' : 'Speech not available'),
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
                    child: _isVoiceLoading
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
                  onPressed: _speechEnabled && !_isVoiceLoading
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
                  onPressed: _isVoiceLoading ? null : _sendVoiceToGemini,
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
                onPressed: _isVoiceLoading ? null : _clearAll,
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

  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header with action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analysis History',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                children: [
                  // This button only appears when you have selected at least one item.
                  if (_isSelectionMode && _selectedTaskIds.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _deleteSelectedTasks,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Selected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // This button toggles selection mode.
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = !_isSelectionMode;
                        _selectedTaskIds.clear();
                      });
                    },
                    icon: Icon(_isSelectionMode ? Icons.done : Icons.select_all),
                    label: Text(_isSelectionMode ? 'Done' : 'Select'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isHistoryLoading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Expanded(
                  child: _history.isEmpty
                      ? const Center(
                          child: Text(
                            'No history yet. Analyze an image or symptoms to save your first entry.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final task = _history[index];
                            final isSelected = _selectedTaskIds.contains(task.id);
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: _isSelectionMode
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedTaskIds.add(task.id!);
                                            } else {
                                              _selectedTaskIds.remove(task.id);
                                            }
                                          });
                                        },
                                      )
                                    : const Icon(Icons.description, color: Colors.deepPurple),
                                title: Text(
                                  task.title.split('. ')[0] + (task.title.split('. ').length > 1 ? '...' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  task.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                // **MODIFICATION HERE:** The delete button is now always visible.
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTask(task.id!),
                                ),
                                onTap: _isSelectionMode
                                    ? () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedTaskIds.remove(task.id);
                                          } else {
                                            _selectedTaskIds.add(task.id!);
                                          }
                                        });
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
          const SizedBox(height: 16),
          // Keep the "Clear All" button for convenience outside of selection mode
          if (!_isSelectionMode)
            ElevatedButton.icon(
              onPressed: _isHistoryLoading ? null : _clearAll,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear All History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}