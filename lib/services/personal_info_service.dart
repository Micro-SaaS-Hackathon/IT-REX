import 'package:shared_preferences/shared_preferences.dart';

class PersonalInfoService {
  static final PersonalInfoService _instance = PersonalInfoService._internal();
  factory PersonalInfoService() => _instance;
  PersonalInfoService._internal();

  String _name = '';
  String _surname = '';
  String _age = '';
  String _sex = '';
  String _country = '';
  String _height = '';
  String _weight = '';
  String _allergies = '';
  String _diseaseHistory = '';

  String get name => _name;
  String get surname => _surname;
  String get age => _age;
  String get sex => _sex;
  String get country => _country;
  String get height => _height;
  String get weight => _weight;
  String get allergies => _allergies;
  String get diseaseHistory => _diseaseHistory;

  Future<void> loadPersonalInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('name') ?? '';
    _surname = prefs.getString('surname') ?? '';
    _age = prefs.getString('age') ?? '';
    _sex = prefs.getString('sex') ?? '';
    _country = prefs.getString('country') ?? '';
    _height = prefs.getString('height') ?? '';
    _weight = prefs.getString('weight') ?? '';
    _allergies = prefs.getString('allergies') ?? '';
    _diseaseHistory = prefs.getString('diseaseHistory') ?? '';
  }

  Future<void> savePersonalInfo({
    required String name,
    required String surname,
    required String age,
    required String sex,
    required String country,
    required String height,
    required String weight,
    required String allergies,
    required String diseaseHistory,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('surname', surname);
    await prefs.setString('age', age);
    await prefs.setString('sex', sex);
    await prefs.setString('country', country);
    await prefs.setString('height', height);
    await prefs.setString('weight', weight);
    await prefs.setString('allergies', allergies);
    await prefs.setString('diseaseHistory', diseaseHistory);

    _name = name;
    _surname = surname;
    _age = age;
    _sex = sex;
    _country = country;
    _height = height;
    _weight = weight;
    _allergies = allergies;
    _diseaseHistory = diseaseHistory;
  }

  String getPersonalContext() {
    final List<String> context = [];
    
    if (_age.isNotEmpty) {
      context.add('Age: $_age');
    }
    if (_sex.isNotEmpty) {
      context.add('Sex: $_sex');
    }
    if (_weight.isNotEmpty || _height.isNotEmpty) {
      context.add('Physical: ${_height.isNotEmpty ? 'Height: $_height' : ''}${_height.isNotEmpty && _weight.isNotEmpty ? ', ' : ''}${_weight.isNotEmpty ? 'Weight: $_weight' : ''}');
    }
    if (_country.isNotEmpty) {
      context.add('Country: $_country');
    }
    if (_allergies.isNotEmpty) {
      context.add('Allergies: $_allergies');
    }
    if (_diseaseHistory.isNotEmpty) {
      context.add('Medical History: $_diseaseHistory');
    }

    return context.isEmpty ? '' : 'Important Patient Information:\n${context.join('\n')}\n\n';
  }
}