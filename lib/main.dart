import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

// Globale Liste für die verfügbaren Kameras
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Fehler beim Laden der Kamera: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aufmass JB',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StartScreen(),
    );
  }
}

// ==========================================
// SEITE 1: Startbildschirm mit Live-Standort
// ==========================================
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String _locationMessage = "Standort wird ermittelt...";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getLiveLocation();
  }

  Future<void> _getLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = "Bitte GPS am Tablet einschalten.";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = "GPS-Berechtigung abgelehnt.";
        });
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _locationMessage = "${place.street ?? ''}, ${place.postalCode ?? ''} ${place.locality ?? ''}";
        });
      }
    } catch (e) {
      setState(() {
        _locationMessage = "Adresse konnte nicht geladen werden.";
      });
    }
  }

  void _openCustomCamera(BuildContext context) {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Kamera gefunden!')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomCameraScreen(
          defaultAddress: _locationMessage,
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    await _getLiveLocation();

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      File imageFile = File(image.path);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditPhotoScreen(
            currentImage: imageFile,
            defaultAddress: _locationMessage,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text('Замеры на стройке (Start)'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.location_pin, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "Текущий адрес (Live-Standort):",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _locationMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              
              TextButton.icon(
                onPressed: _getLiveLocation,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Обновить адрес'),
              ),

              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _openCustomCamera(context),
                  icon: const Icon(Icons.camera_alt, size: 28),
                  label: const Text('Сделать фото', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () => _pickFromGallery(context),
                  icon: const Icon(Icons.photo_library, size: 28),
                  label: const Text('Выбрать из галереи', style: TextStyle(fontSize: 18)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SEITE 1.5: Eigene Live-Kamera 
// ==========================================
class CustomCameraScreen extends StatefulWidget {
  final String defaultAddress;
  const CustomCameraScreen({super.key, required this.defaultAddress});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndGo() async {
    if (_isTakingPicture) return;

    try {
      setState(() {
        _isTakingPicture = true;
      });
      await _initializeControllerFuture;
      
      final image = await _controller.takePicture();
      
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EditPhotoScreen(
            currentImage: File(image.path),
            defaultAddress: widget.defaultAddress,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Fehler beim Fotografieren: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: CameraPreview(_controller),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30.0),
                      child: GestureDetector(
                        onTap: _takePictureAndGo,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.8),
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: _isTakingPicture 
                              ? const Center(child: CircularProgressIndicator()) 
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
          },
        ),
      ),
    );
  }
}

// ==========================================
// SEITE 2: Bearbeitungsseite (Vollbild Foto)
// ==========================================
class EditPhotoScreen extends StatefulWidget {
  final File currentImage;
  final String defaultAddress;

  const EditPhotoScreen({
    super.key,
    required this.currentImage,
    required this.defaultAddress,
  });

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  
  String _lengthText = '';
  String _widthText = '';
  String _depthText = '';
  
  String _noteText1 = '';
  String _noteText2 = '';
  String _noteText3 = '';
  String _stampedAddress = '';

  bool _isSaving = false;
  String _activeToolKey = 'Länge';

  final Map<String, String> _toolOptionsMap = {
    'Длина (Länge)': 'Länge',
    'Ширина (Breite)': 'Breite',
    'Глубина (Tiefe)': 'Tiefe',
    '1. Заметка (1. Notiz)': 'Notiz 1',
    '2. Заметка (2. Notiz)': 'Notiz 2',
    '3. Заметка (3. Notiz)': 'Notiz 3',
    'Адрес (Standort)': 'Standort',
  };

  Offset? _lengthStart, _lengthEnd;
  Offset? _widthStart, _widthEnd;
  Offset? _depthStart, _depthEnd;
  
  Offset? _notePos1;
  Offset? _notePos2;
  Offset? _notePos3;
  Offset? _addressPos;

  Future<void> _saveToGallery(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final Uint8List? capturedBytes = await _screenshotController.capture(pixelRatio: 5.0);
      
      if (capturedBytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final filePath = '${tempDir.path}/aufmass_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(capturedBytes);

        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        
        await Gal.putImage(file.path, album: 'Aufmass JB');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сохранено в альбом "Aufmass JB"!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сохранении: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openDataInputScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataInputScreen(
          length: _lengthText,
          width: _widthText,
          depth: _depthText,
          note1: _noteText1,
          note2: _noteText2,
          note3: _noteText3,
          address: _stampedAddress.isNotEmpty ? _stampedAddress : widget.defaultAddress,
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _lengthText = result['length'] ?? '';
        _widthText = result['width'] ?? '';
        _depthText = result['depth'] ?? '';
        _noteText1 = result['note1'] ?? '';
        _noteText2 = result['note2'] ?? '';
        _noteText3 = result['note3'] ?? '';
        _stampedAddress = result['address'] ?? '';
      });
    }
  }

  String _getCurrentToolDisplayValue() {
    for (var entry in _toolOptionsMap.entries) {
      if (entry.value == _activeToolKey) {
        return entry.key;
      }
    }
    return _toolOptionsMap.keys.first;
  }

  void _handleTouch(Offset localPosition) {
    setState(() {
      if (_activeToolKey == 'Notiz 1') {
        _notePos1 = localPosition;
      } else if (_activeToolKey == 'Notiz 2') {
        _notePos2 = localPosition;
      } else if (_activeToolKey == 'Notiz 3') {
        _notePos3 = localPosition;
      } else if (_activeToolKey == 'Standort') {
        _addressPos = localPosition;
      }
    });
  }

  void _handlePan(Offset localPosition, bool isStart) {
    setState(() {
      if (_activeToolKey == 'Länge') {
        if (isStart) _lengthStart = localPosition;
        _lengthEnd = localPosition;
      } else if (_activeToolKey == 'Breite') {
        if (isStart) _widthStart = localPosition;
        _widthEnd = localPosition;
      } else if (_activeToolKey == 'Tiefe') {
        if (isStart) _depthStart = localPosition;
        _depthEnd = localPosition;
      } else if (_activeToolKey == 'Notiz 1') {
        _notePos1 = localPosition;
      } else if (_activeToolKey == 'Notiz 2') {
        _notePos2 = localPosition;
      } else if (_activeToolKey == 'Notiz 3') {
        _notePos3 = localPosition;
      } else if (_activeToolKey == 'Standort') {
        _addressPos = localPosition;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Режим: $_activeToolKey'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            tooltip: 'Ввести значения',
            onPressed: _openDataInputScreen,
          ),
          IconButton(
            icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_alt),
            tooltip: 'Сохранить',
            onPressed: _isSaving ? null : () => _saveToGallery(context),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Text("Режим:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _getCurrentToolDisplayValue(),
                    isDense: true,
                    isExpanded: true,
                    items: _toolOptionsMap.keys.map((String russianDisplay) {
                      return DropdownMenuItem<String>(
                        value: russianDisplay,
                        child: Text(russianDisplay, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      );
                    }).toList(),
                    onChanged: (String? selectedRussianDisplay) {
                      if (selectedRussianDisplay != null) {
                        setState(() {
                          _activeToolKey = _toolOptionsMap[selectedRussianDisplay]!;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openDataInputScreen,
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('Данные', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ClipRRect(
              child: Screenshot(
                controller: _screenshotController,
                child: FutureBuilder<Size>(
                  future: _getImageSize(widget.currentImage),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final imageSize = snapshot.data!;
                    
                    return Center(
                      child: AspectRatio(
                        aspectRatio: imageSize.width / imageSize.height,
                        child: GestureDetector(
                          onTapDown: (details) => _handleTouch(details.localPosition),
                          onPanStart: (details) => _handlePan(details.localPosition, true),
                          onPanUpdate: (details) => _handlePan(details.localPosition, false),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                widget.currentImage,
                                fit: BoxFit.contain, 
                              ),
                              CustomPaint(
                                painter: RedDimensionPainter(
                                  lengthStart: _lengthStart, lengthEnd: _lengthEnd, lengthLabel: "Länge: $_lengthText",
                                  widthStart: _widthStart, widthEnd: _widthEnd, widthLabel: "Breite: $_widthText",
                                  depthStart: _depthStart, depthEnd: _depthEnd, depthLabel: "Tiefe: $_depthText",
                                  notePos1: _notePos1, noteLabel1: _noteText1,
                                  notePos2: _notePos2, noteLabel2: _noteText2,
                                  notePos3: _notePos3, noteLabel3: _noteText3,
                                  addressPos: _addressPos, addressLabel: _stampedAddress,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Size> _getImageSize(File file) async {
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }
}

// ==========================================
// SEITE 3: Eingabebereich mit 3 getrennten Notizen
// ==========================================
class DataInputScreen extends StatefulWidget {
  final String length;
  final String width;
  final String depth;
  final String note1;
  final String note2;
  final String note3;
  final String address;

  const DataInputScreen({
    super.key,
    required this.length,
    required this.width,
    required this.depth,
    required this.note1,
    required this.note2,
    required this.note3,
    required this.address,
  });

  @override
  State<DataInputScreen> createState() => _DataInputScreenState();
}

class _DataInputScreenState extends State<DataInputScreen> {
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _depthController;
  
  late TextEditingController _noteController1;
  late TextEditingController _noteController2;
  late TextEditingController _noteController3;
  
  late TextEditingController _addressController;

  // Nur für Block 1 (Versorger)
  final Map<String, String> _versorgerOptionsMap = {
    'Вода (Wasser)': 'Wasser',
    'Газ (Gas)': 'Gas',
    'Электричество (Strom)': 'Strom',
  };

  // Nur für Block 2 (Material)
  final Map<String, String> _materialOptionsMap = {
    'Асфальт (Asphalt)': 'Asphalt',
    'Бетонная плитка (Betonsteinpflaster)': 'Betonsteinpflaster',
    'Бетонный щебень (Betonschotter)': 'Betonschotter',
    'Бордюр (Bordstein)': 'Bordstein',
    'Дробленый песок (Brechsand)': 'Brechsand',
    'Грунт (Boden)': 'Boden',
    'Кабель (Kabel)': 'Kabel',
    'Клинкер (Klinkerpflaster)': 'Klinkerpflaster',
    'Колодец (Schacht)': 'Schacht',
    'Лоток (Rinne)': 'Rinne',
    'Минеральная смесь (Mineralgemisch)': 'Mineralgemisch',
    'Трубы KG (KG Rohre)': 'KG Rohre',
    'Трубы KG 2000 (KG 2000 Rohre)': 'KG 2000 Rohre',
    'Узловая брусчатка (Verbundsteinpflaster)': 'Verbundsteinpflaster',
    'Засыпной песок (Füllsand)': 'Füllsand',
  };

  // Nur für Block 3 (Tätigkeit)
  final Map<String, String> _taetigkeitOptionsMap = {
    'Установлено (gesetzt)': 'gesetzt',
    'Экскаватор (Bagger)': 'Bagger',
    'Погрузчик (Radlader)': 'Radlader',
    'Насос (Pumpe)': 'Pumpe',
    'Часы (Stunden)': 'Stunden',
    'Демонтировано (aufgenommen)': 'aufgenommen',
    'Колодец/Яма (Grube)': 'Grube',
    'Почасовая оплата (Stundenlohn)': 'Stundenlohn',
    'Траншея (Graben)': 'Graben',
    'Уложено (verlegt)': 'verlegt',
    'Шурф (Suchschachtung)': 'Suchschachtung',
  };

  @override
  void initState() {
    super.initState();
    _lengthController = TextEditingController(text: widget.length);
    _widthController = TextEditingController(text: widget.width);
    _depthController = TextEditingController(text: widget.depth);
    _noteController1 = TextEditingController(text: widget.note1);
    _noteController2 = TextEditingController(text: widget.note2);
    _noteController3 = TextEditingController(text: widget.note3);
    _addressController = TextEditingController(text: widget.address);
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _noteController1.dispose();
    _noteController2.dispose();
    _noteController3.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    Navigator.pop(context, {
      'length': _lengthController.text,
      'width': _widthController.text,
      'depth': _depthController.text,
      'note1': _noteController1.text,
      'note2': _noteController2.text,
      'note3': _noteController3.text,
      'address': _addressController.text,
    });
  }

  void _appendToNote(String? selectedRussianKey, TextEditingController controller, Map<String, String> mapToUse) {
    if (selectedRussianKey != null) {
      final germanValue = mapToUse[selectedRussianKey]!;
      setState(() {
        if (controller.text.isEmpty) {
          controller.text = germanValue;
        } else {
          controller.text = "${controller.text} - $germanValue";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text('Ввод данных (Maße & Notizen)', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 26),
            tooltip: 'Принять',
            onPressed: _saveAndReturn,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: ListView(
          children: [
            TextField(
              controller: _lengthController,
              decoration: const InputDecoration(
                labelText: 'Длина (Länge)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _widthController,
              decoration: const InputDecoration(
                labelText: 'Ширина (Breite)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _depthController,
              decoration: const InputDecoration(
                labelText: 'Глубина (Tiefe)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 32, thickness: 2),

            // =========================
            // BLOCK 1 (Versorger)
            // =========================
            TextField(
              controller: _noteController1,
              decoration: InputDecoration(
                labelText: '1. Примечание (1. Auswahl Versorger)',
                labelStyle: const TextStyle(fontSize: 14),
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () => _noteController1.clear(),
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '1. Выбор поставщика (1. Auswahl Versorger)',
                labelStyle: TextStyle(fontSize: 14),
                isDense: true,
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Выберите поставщика...', style: TextStyle(fontSize: 16)),
                  items: _versorgerOptionsMap.keys.map((String russianLabel) {
                    return DropdownMenuItem<String>(
                      value: russianLabel,
                      child: Text(russianLabel, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (val) => _appendToNote(val, _noteController1, _versorgerOptionsMap),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =========================
            // BLOCK 2 (Material)
            // =========================
            TextField(
              controller: _noteController2,
              decoration: InputDecoration(
                labelText: '2. Примечание (2. Material)',
                labelStyle: const TextStyle(fontSize: 14),
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () => _noteController2.clear(),
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '2. Выбор материала (2. Auswahl Material)',
                labelStyle: TextStyle(fontSize: 14),
                isDense: true,
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Выберите материал...', style: TextStyle(fontSize: 16)),
                  items: _materialOptionsMap.keys.map((String russianLabel) {
                    return DropdownMenuItem<String>(
                      value: russianLabel,
                      child: Text(russianLabel, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (val) => _appendToNote(val, _noteController2, _materialOptionsMap),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =========================
            // BLOCK 3 (Tätigkeit)
            // =========================
            TextField(
              controller: _noteController3,
              decoration: InputDecoration(
                labelText: '3. Примечание (3. Tätigkeit)',
                labelStyle: const TextStyle(fontSize: 14),
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () => _noteController3.clear(),
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '3. Выбор деятельности (3. Auswahl Tätigkeit)',
                labelStyle: TextStyle(fontSize: 14),
                isDense: true,
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Выберите деятельность...', style: TextStyle(fontSize: 16)),
                  items: _taetigkeitOptionsMap.keys.map((String russianLabel) {
                    return DropdownMenuItem<String>(
                      value: russianLabel,
                      child: Text(russianLabel, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (val) => _appendToNote(val, _noteController3, _taetigkeitOptionsMap),
                ),
              ),
            ),
            const Divider(height: 32, thickness: 2),

            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Адрес / Объект',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                  onPressed: () => _addressController.clear(),
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveAndReturn,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Принять и вернуться', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PAINTER FÜR DIE LINIEN UND SCHRIFTEN
// ==========================================
class RedDimensionPainter extends CustomPainter {
  final Offset? lengthStart, lengthEnd;
  final String lengthLabel;
  final Offset? widthStart, widthEnd;
  final String widthLabel;
  final Offset? depthStart, depthEnd;
  final String depthLabel;
  
  final Offset? notePos1;
  final String noteLabel1;
  final Offset? notePos2;
  final String noteLabel2;
  final Offset? notePos3;
  final String noteLabel3;
  
  final Offset? addressPos;
  final String addressLabel;

  RedDimensionPainter({
    this.lengthStart, this.lengthEnd, required this.lengthLabel,
    this.widthStart, this.widthEnd, required this.widthLabel,
    this.depthStart, this.depthEnd, required this.depthLabel,
    this.notePos1, required this.noteLabel1,
    this.notePos2, required this.noteLabel2,
    this.notePos3, required this.noteLabel3,
    this.addressPos, required this.addressLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 800.0;

    if (lengthStart != null && lengthEnd != null) {
      _drawArrowLineWithParallelLabel(canvas, lengthStart!, lengthEnd!, lengthLabel, twoArrows: true, scale: scale);
    }
    if (widthStart != null && widthEnd != null) {
      _drawArrowLineWithParallelLabel(canvas, widthStart!, widthEnd!, widthLabel, twoArrows: true, scale: scale);
    }
    if (depthStart != null && depthEnd != null) {
      _drawArrowLineWithParallelLabel(canvas, depthStart!, depthEnd!, depthLabel, twoArrows: false, scale: scale);
    }
    
    if (notePos1 != null && noteLabel1.isNotEmpty) {
      _drawTextBadge(canvas, notePos1!, noteLabel1, Colors.red, scale: scale);
    }
    if (notePos2 != null && noteLabel2.isNotEmpty) {
      _drawTextBadge(canvas, notePos2!, noteLabel2, Colors.red, scale: scale);
    }
    if (notePos3 != null && noteLabel3.isNotEmpty) {
      _drawTextBadge(canvas, notePos3!, noteLabel3, Colors.red, scale: scale);
    }
    
    if (addressPos != null && addressLabel.isNotEmpty) {
      _drawTextBadge(canvas, addressPos!, addressLabel, Colors.black87, scale: scale);
    }
  }

  void _drawArrowLineWithParallelLabel(Canvas canvas, Offset start, Offset end, String label, {required bool twoArrows, required double scale}) {
    if ((end - start).distance < 5 || label.isEmpty || label == "Länge: " || label == "Breite: " || label == "Tiefe: ") {
      _drawPlainLine(canvas, start, end, twoArrows, scale);
      return;
    }

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = math.max(4.0, 5.0 * scale)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(start, end, paint);
    if (twoArrows) {
      _drawArrowHead(canvas, start, end, paint, scale);
    }
    _drawArrowHead(canvas, end, start, paint, scale);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    double angle = math.atan2(dy, dx);

    if (dx < 0) {
      angle += math.pi;
    }

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        fontSize: math.max(18.0, 26.0 * scale),
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final paddingH = 20.0 * scale; 
    final paddingV = 12.0 * scale; 

    final badgeWidth = textPainter.width + (paddingH * 2);
    final badgeHeight = textPainter.height + (paddingV * 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final rect = Rect.fromCenter(
      center: const Offset(0, 0),
      width: badgeWidth,
      height: badgeHeight,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(8.0 * scale)); 

    final bgPaint = Paint()
      ..color = Colors.red
      ..isAntiAlias = true;
      
    canvas.drawRRect(rrect, bgPaint);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

    canvas.restore();
  }

  void _drawPlainLine(Canvas canvas, Offset start, Offset end, bool twoArrows, double scale) {
    if ((end - start).distance < 5) return;
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = math.max(4.0, 5.0 * scale)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(start, end, paint);
    if (twoArrows) {
      _drawArrowHead(canvas, start, end, paint, scale);
    }
    _drawArrowHead(canvas, end, start, paint, scale);
  }

  void _drawTextBadge(Canvas canvas, Offset pos, String text, Color bgColor, {required double scale}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: math.max(18.0, 26.0 * scale),
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final paddingH = 20.0 * scale; 
    final paddingV = 12.0 * scale; 

    final rect = Rect.fromCenter(
      center: pos,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(8.0 * scale)); 

    final bgPaint = Paint()
      ..color = bgColor
      ..isAntiAlias = true;
      
    canvas.drawRRect(rrect, bgPaint);

    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset from, Paint paint, double scale) {
    final double arrowSize = math.max(18.0, 25.0 * scale);
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);

    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(
      tip.dx - arrowSize * math.cos(angle - math.pi / 6),
      tip.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    path.lineTo(
      tip.dx - arrowSize * math.cos(angle + math.pi / 6),
      tip.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    path.close();

    final arrowPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}