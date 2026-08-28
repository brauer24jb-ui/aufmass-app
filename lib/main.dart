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
      title: 'Aufmass',
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
    
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) {
      File imageFile = File(photo.path);
      _navigateToEdit(context, imageFile);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    await _getLiveLocation();

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
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
// SEITE 2: Bearbeitungsseite
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
  
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
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

  String _stampedAddress = '';
  Offset? _addressPos;

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

  Future<void> _saveToGallery(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final Uint8List? capturedBytes = await _screenshotController.capture(pixelRatio: 3.0);
      
      if (capturedBytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final filePath = '${tempDir.path}/aufmass_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(capturedBytes);

        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        
        await Gal.putImage(file.path, album: 'Aufmass');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сохранено в альбом "Aufmass"!'),
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

  void _openAddressDialog() {
    final TextEditingController addrController = TextEditingController(text: widget.defaultAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Адрес (Standort eintragen)'),
        content: TextField(
          controller: addrController,
          decoration: const InputDecoration(
            labelText: 'Адрес / Объект',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _stampedAddress = addrController.text;
                _activeToolKey = 'Standort';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Нажмите на фото, чтобы разместить адрес!'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Принять'),
          ),
        ],
      ),
    );
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
        title: const Text('Aufmass - Редактирование'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 12),
                        label: const Text('Назад', style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    SizedBox(
                      height: 28,
                      child: DropdownButton<String>(
                        value: _getCurrentToolDisplayValue(),
                        isDense: true,
                        items: _toolOptionsMap.keys.map((String russianDisplay) {
                          return DropdownMenuItem<String>(
                            value: russianDisplay,
                            child: Text("Режим: $russianDisplay", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
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
                    const SizedBox(width: 4),

                    SizedBox(
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: _openAddressDialog,
                        icon: const Icon(Icons.pin_drop, size: 12, color: Colors.blue),
                        label: const Text('Адрес', style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                    const Spacer(),

                    SizedBox(
                      height: 28,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _saveToGallery(context),
                        icon: _isSaving 
                            ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_alt, size: 12),
                        label: Text(_isSaving ? '...' : 'Сохранить', style: const TextStyle(fontSize: 10)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _lengthController,
                          decoration: InputDecoration(
                            labelText: 'Длина (Länge)',
                            labelStyle: const TextStyle(fontSize: 10),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() { _lengthController.clear(); _lengthStart = _lengthEnd = null; }),
                            ),
                          ),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),

                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _widthController,
                          decoration: InputDecoration(
                            labelText: 'Ширина (Breite)',
                            labelStyle: const TextStyle(fontSize: 10),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() { _widthController.clear(); _widthStart = _widthEnd = null; }),
                            ),
                          ),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),

                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _depthController,
                          decoration: InputDecoration(
                            labelText: 'Глубина (Tiefe)',
                            labelStyle: const TextStyle(fontSize: 10),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() { _depthController.clear(); _depthStart = _depthEnd = null; }),
                            ),
                          ),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Примечание / Деталь (Notiz / Bauteil)',
                            labelStyle: const TextStyle(fontSize: 10),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, size: 12, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() { _noteController.clear(); _notePos = null; }),
                            ),
                          ),
                          style: const TextStyle(fontSize: 11),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),

                    SizedBox(
                      height: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isDense: true,
                            hint: const Text('Быстрый выбор', style: TextStyle(fontSize: 10)),
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
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.red.shade100,
            width: double.infinity,
            child: Text(
              "Активный режим: **$_activeToolKey** (нанесите линию / разместите текст)",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 84.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Screenshot(
                  controller: _screenshotController,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FutureBuilder<Size>(
                        future: _getImageSize(widget.currentImage),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final imageSize = snapshot.data!;
                          
                          final double aspectContainer = constraints.maxWidth / constraints.maxHeight;
                          final double aspectImage = imageSize.width / imageSize.height;

                          double renderWidth, renderHeight;
                          if (aspectImage > aspectContainer) {
                            renderWidth = constraints.maxWidth;
                            renderHeight = constraints.maxWidth / aspectImage;
                          } else {
                            renderHeight = constraints.maxHeight;
                            renderWidth = constraints.maxHeight * aspectImage;
                          }

                          return Center(
                            child: SizedBox(
                              width: renderWidth,
                              height: renderHeight,
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
                                      fit: BoxFit.fill,
                                    ),

                                    CustomPaint(
                                      painter: RedDimensionPainter(
                                        lengthStart: _lengthStart, lengthEnd: _lengthEnd, lengthLabel: "Länge: ${_lengthController.text}",
                                        widthStart: _widthStart, widthEnd: _widthEnd, widthLabel: "Breite: ${_widthController.text}",
                                        depthStart: _depthStart, depthEnd: _depthEnd, depthLabel: "Tiefe: ${_depthController.text}",
                                        notePos: _notePos, noteLabel: _noteController.text,
                                        addressPos: _addressPos, addressLabel: _stampedAddress,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
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
    // Basis-Skalierungsfaktor für deutliche Lesbarkeit auf hochauflösenden Tablet-Fotos
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

    // Deutlich dickere und kräftigere Linien
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = math.max(6.0, 7.5 * scale)
      ..strokeCap = StrokeCap.round;

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
        // Deutlich größere Schrift für beste Lesbarkeit
        fontSize: math.max(20.0, 32.0 * scale),
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final paddingH = 16.0 * scale;
    final paddingV = 10.0 * scale;

    final rect = Rect.fromCenter(
      center: pos,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(rect, bgPaint);

    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Offset from, Paint paint, double scale) {
    // Größere Pfeilspitzen passend zu den dicken Linien
    final double arrowSize = math.max(20.0, 30.0 * scale);
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
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}