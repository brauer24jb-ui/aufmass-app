import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
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

  Future<void> _pickFromCamera(BuildContext context) async {
    await _getLiveLocation();
    
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
    if (photo != null && mounted) {
      File imageFile = File(photo.path);
      _navigateToEdit(context, imageFile);
    }
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
      _navigateToEdit(context, imageFile);
    }
  }

  void _navigateToEdit(BuildContext context, File imageFile) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  onPressed: () => _pickFromCamera(context),
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
  String _noteText = '';
  String _stampedAddress = '';

  bool _isSaving = false;
  String _activeToolKey = 'Länge';

  final Map<String, String> _toolOptionsMap = {
    'Длина (Länge)': 'Länge',
    'Ширина (Breite)': 'Breite',
    'Глубина (Tiefe)': 'Tiefe',
    'Заметка / Деталь (Notiz / Bauteil)': 'Notiz',
    'Адрес (Standort)': 'Standort',
  };

  Offset? _lengthStart, _lengthEnd;
  Offset? _widthStart, _widthEnd;
  Offset? _depthStart, _depthEnd;
  Offset? _notePos;
  Offset? _addressPos;

  Future<void> _saveToGallery(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // WICHTIG: Auflösung auf 5.0 hochgeschraubt für gestochen scharfe Bilder!
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
          note: _noteText,
          address: _stampedAddress.isNotEmpty ? _stampedAddress : widget.defaultAddress,
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _lengthText = result['length'] ?? '';
        _widthText = result['width'] ?? '';
        _depthText = result['depth'] ?? '';
        _noteText = result['note'] ?? '';
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
                      // WICHTIG: AspectRatio verhindert jegliches Verziehen des Bildes!
                      child: AspectRatio(
                        aspectRatio: imageSize.width / imageSize.height,
                        child: GestureDetector(
                          onTapDown: (details) {
                            final pos = details.localPosition;
                            setState(() {
                              if (_activeToolKey == 'Notiz') {
                                _notePos = pos;
                              } else if (_activeToolKey == 'Standort') {
                                _addressPos = pos;
                              }
                            });
                          },
                          onPanStart: (details) {
                            setState(() {
                              if (_activeToolKey == 'Länge') {
                                _lengthStart = details.localPosition;
                                _lengthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Breite') {
                                _widthStart = details.localPosition;
                                _widthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Tiefe') {
                                _depthStart = details.localPosition;
                                _depthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Notiz') {
                                _notePos = details.localPosition;
                              } else if (_activeToolKey == 'Standort') {
                                _addressPos = details.localPosition;
                              }
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              if (_activeToolKey == 'Länge') {
                                _lengthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Breite') {
                                _widthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Tiefe') {
                                _depthEnd = details.localPosition;
                              } else if (_activeToolKey == 'Notiz') {
                                _notePos = details.localPosition;
                              } else if (_activeToolKey == 'Standort') {
                                _addressPos = details.localPosition;
                              }
                            });
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                widget.currentImage,
                                fit: BoxFit.contain, // Stellt sicher, dass das Bild nicht gestreckt wird
                              ),

                              CustomPaint(
                                painter: RedDimensionPainter(
                                  lengthStart: _lengthStart, lengthEnd: _lengthEnd, lengthLabel: "Länge: $_lengthText",
                                  widthStart: _widthStart, widthEnd: _widthEnd, widthLabel: "Breite: $_widthText",
                                  depthStart: _depthStart, depthEnd: _depthEnd, depthLabel: "Tiefe: $_depthText",
                                  notePos: _notePos, noteLabel: _noteText,
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
// SEITE 3: Eingabebereich mit hellblauem Hintergrund
// ==========================================
class DataInputScreen extends StatefulWidget {
  final String length;
  final String width;
  final String depth;
  final String note;
  final String address;

  const DataInputScreen({
    super.key,
    required this.length,
    required this.width,
    required this.depth,
    required this.note,
    required this.address,
  });

  @override
  State<DataInputScreen> createState() => _DataInputScreenState();
}

class _DataInputScreenState extends State<DataInputScreen> {
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _depthController;
  late TextEditingController _noteController;
  late TextEditingController _addressController;

  final Map<String, String> _noteOptionsMap = {
    'Асфальт (Asphalt)': 'Asphalt',
    'Бетонная плитка (Betonsteinpflaster)': 'Betonsteinpflaster',
    'Бетонный щебень (Betonschotter)': 'Betonschotter',
    'Бордюр (Bordstein)': 'Bordstein',
    'Дробленый песок (Brechsand)': 'Brechsand',
    'Вода (Wasser)': 'Wasser',
    'Газ (Gas)': 'Gas',
    'Грунт (Boden)': 'Boden',
    'Демонтировано (aufgenommen)': 'aufgenommen',
    'Кабель (Kabel)': 'Kabel',
    'Клинкер (Klinkerpflaster)': 'Klinkerpflaster',
    'Колодец/Яма (Grube)': 'Grube',
    'Лоток (Rinne)': 'Rinne',
    'Почасовая оплата (Stundenlohn)': 'Stundenlohn',
    'Минеральная смесь (Mineralgemisch)': 'Mineralgemisch',
    'Траншея (Graben)': 'Graben',
    'Узловая брусчатка (Verbundsteinpflaster)': 'Verbundsteinpflaster',
    'Уложено (verlegt)': 'verlegt',
    'Электричество (Strom)': 'Strom',
    'Засыпной песок (Füllsand)': 'Füllsand',
    'Шурф (Suchschachtung)': 'Suchschachtung',
  };

  @override
  void initState() {
    super.initState();
    _lengthController = TextEditingController(text: widget.length);
    _widthController = TextEditingController(text: widget.width);
    _depthController = TextEditingController(text: widget.depth);
    _noteController = TextEditingController(text: widget.note);
    _addressController = TextEditingController(text: widget.address);
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _noteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    Navigator.pop(context, {
      'length': _lengthController.text,
      'width': _widthController.text,
      'depth': _depthController.text,
      'note': _noteController.text,
      'address': _addressController.text,
    });
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
            const SizedBox(height: 24),

            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Примечание (Notiz / Bauteil)',
                labelStyle: const TextStyle(fontSize: 11),
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () => _noteController.clear(),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),

            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Быстрый выбор (Schnellwahl)',
                labelStyle: TextStyle(fontSize: 10),
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
                  hint: const Text('Выберите материал...', style: TextStyle(fontSize: 11)),
                  items: _noteOptionsMap.keys.map((String russianLabel) {
                    return DropdownMenuItem<String>(
                      value: russianLabel,
                      child: Text(russianLabel, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                  onChanged: (String? selectedRussianKey) {
                    if (selectedRussianKey != null) {
                      final germanValue = _noteOptionsMap[selectedRussianKey]!;
                      setState(() {
                        if (_noteController.text.isEmpty) {
                          _noteController.text = germanValue;
                        } else {
                          _noteController.text = "${_noteController.text} - $germanValue";
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

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
              style: const TextStyle(fontSize: 14),
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
  final Offset? notePos;
  final String noteLabel;
  final Offset? addressPos;
  final String addressLabel;

  RedDimensionPainter({
    this.lengthStart, this.lengthEnd, required this.lengthLabel,
    this.widthStart, this.widthEnd, required this.widthLabel,
    this.depthStart, this.depthEnd, required this.depthLabel,
    this.notePos, required this.noteLabel,
    this.addressPos, required this.addressLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 800.0;

    if (lengthStart != null && lengthEnd != null) {
      _drawArrowLineWithLabel(canvas, lengthStart!, lengthEnd!, lengthLabel, twoArrows: true, scale: scale);
    }
    if (widthStart != null && widthEnd != null) {
      _drawArrowLineWithLabel(canvas, widthStart!, widthEnd!, widthLabel, twoArrows: true, scale: scale);
    }
    if (depthStart != null && depthEnd != null) {
      _drawArrowLineWithLabel(canvas, depthStart!, depthEnd!, depthLabel, twoArrows: false, scale: scale);
    }
    if (notePos != null && noteLabel.isNotEmpty) {
      _drawTextBadge(canvas, notePos!, noteLabel, Colors.red, scale: scale);
    }
    if (addressPos != null && addressLabel.isNotEmpty) {
      _drawTextBadge(canvas, addressPos!, "Standort: $addressLabel", Colors.black87, scale: scale);
    }
  }

  void _drawArrowLineWithLabel(Canvas canvas, Offset start, Offset end, String label, {required bool twoArrows, required double scale}) {
    if ((end - start).distance < 5) return;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = math.max(4.0, 5.0 * scale) // Ein kleines bisschen dünner für mehr Schärfe
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true; // Kantenglättung für scharfe Linien

    canvas.drawLine(start, end, paint);
    if (twoArrows) {
      _drawArrowHead(canvas, start, end, paint, scale);
    }
    _drawArrowHead(canvas, end, start, paint, scale);

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    _drawTextBadge(canvas, center, label, Colors.red, scale: scale);
  }

  void _drawTextBadge(Canvas canvas, Offset pos, String text, Color bgColor, {required double scale}) {
    final textSpan = TextSpan(
      text: "  $text  ",
      style: TextStyle(
        color: Colors.white,
        fontSize: math.max(18.0, 26.0 * scale),
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final paddingH = 14.0 * scale;
    final paddingV = 8.0 * scale;

    final rect = Rect.fromCenter(
      center: pos,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );
    final bgPaint = Paint()
      ..color = bgColor
      ..isAntiAlias = true;
      
    canvas.drawRect(rect, bgPaint);

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