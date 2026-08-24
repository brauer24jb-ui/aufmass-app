import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const AufmassApp());
}

class AufmassApp extends StatelessWidget {
  const AufmassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baustellen Aufmass',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AufmassHomePage(),
    );
  }
}

class MassLinie {
  Offset start;
  Offset end;
  bool beidseitigerPfeil; 
  String wert;

  MassLinie({
    required this.start,
    required this.end,
    required this.beidseitigerPfeil,
    this.wert = '',
  });

  bool traegtPunkt(Offset p) {
    final dLine = (end - start).distance;
    if (dLine == 0) return false;
    final d1 = (p - start).distance;
    final d2 = (p - end).distance;
    return (d1 + d2 - dLine).abs() < 10.0;
  }
}

class PlaziertesTextElement {
  String text;
  Offset position;

  PlaziertesTextElement({required this.text, required this.position});

  bool traegtPunkt(Offset p) {
    return (p - position).distance < 30.0;
  }
}

class AufmassHomePage extends StatefulWidget {
  const AufmassHomePage({super.key});

  @override
  State<AufmassHomePage> createState() => _AufmassHomePageState();
}

class _AufmassHomePageState extends State<AufmassHomePage> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final List<MassLinie> _linien = [];
  final List<PlaziertesTextElement> _textElemente = [];
  
  bool _beidseitigAktiv = true;
  Offset? _drawingStart;
  Offset? _drawingCurrent;
  
  String _aktiverModus = 'linie'; 
  final TextEditingController _dialogTextController = TextEditingController();

  String _standortInfo = '';

  Future<void> _standortErmitteln() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _standortInfo = 'GPS-Dienste deaktiviert');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _standortInfo = 'Standort-Berechtigung verweigert');
          return;
        }
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _standortInfo = 'GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() => _standortInfo = 'Standort nicht verfügbar');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _linien.clear();
        _textElemente.clear();
        _standortInfo = 'Standort wird ermittelt...';
      });
      await _standortErmitteln();
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _linien.clear();
        _textElemente.clear();
        _standortInfo = 'Ausgewähltes Bild (Galerie)';
      });
    }
  }

  void _masseingabeDialog(Offset start, Offset end, bool beidseitig) {
    _dialogTextController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(beidseitig ? 'Mass eingeben (Länge / Breite)' : 'Mass eingeben (Tiefe)'),
        content: TextField(
          controller: _dialogTextController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Wert mit Einheit (z.B. 4.50 m)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_dialogTextController.text.isNotEmpty) {
                setState(() {
                  _linien.add(MassLinie(
                    start: start,
                    end: end,
                    beidseitigerPfeil: beidseitig,
                    wert: _dialogTextController.text,
                  ));
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  void _textHinzufuegenDialog(Offset position) {
    String ausgewaehlteKategorie = 'Graben';
    _dialogTextController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Text / Notiz aufs Bild wählen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: ausgewaehlteKategorie,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Grube', child: Text('Grube')),
                  DropdownMenuItem(value: 'Graben', child: Text('Graben')),
                  DropdownMenuItem(value: 'Suchschachtung', child: Text('Suchschachtung')),
                  DropdownMenuItem(value: 'Eigener Text', child: Text('Eigener Text...')),
                ],
                onChanged: (val) {
                  setStateDialog(() {
                    ausgewaehlteKategorie = val!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (ausgewaehlteKategorie == 'Eigener Text')
                TextField(
                  controller: _dialogTextController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Eigenen Text eingeben',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                final textEintrag = (ausgewaehlteKategorie == 'Eigener Text')
                    ? _dialogTextController.text
                    : ausgewaehlteKategorie;

                if (textEintrag.isNotEmpty) {
                  setState(() {
                    _textElemente.add(PlaziertesTextElement(
                      text: textEintrag,
                      position: position,
                    ));
                    _aktiverModus = 'linie';
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _elementAntippenZumLoeschen(Offset position) {
    setState(() {
      final linieEntfernen = _linien.where((l) => l.traegtPunkt(position)).toList();
      if (linieEntfernen.isNotEmpty) {
        _linien.remove(linieEntfernen.first);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maßlinie gelöscht'), duration: Duration(milliseconds: 800)),
        );
        return;
      }

      final textEntfernen = _textElemente.where((t) => t.traegtPunkt(position)).toList();
      if (textEntfernen.isNotEmpty) {
        _textElemente.remove(textEntfernen.first);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text / Notiz gelöscht'), duration: Duration(milliseconds: 800)),
        );
        return;
      }
    });
  }

  void _speichern() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aufmass mit eingezeichneten Daten gespeichert!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baustellen Aufmass Pro - GPS'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto aufnehmen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Bild auswählen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedImage != null) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('↔ Maßlinie Beidseitig (L/B)'),
                    selected: _aktiverModus == 'linie' && _beidseitigAktiv,
                    onSelected: (val) { setState(() { _aktiverModus = 'linie'; _beidseitigAktiv = true; }); },
                  ),
                  ChoiceChip(
                    label: const Text('→ Maßlinie Einseitig (Tiefe)'),
                    selected: _aktiverModus == 'linie' && !_beidseitigAktiv,
                    onSelected: (val) { setState(() { _aktiverModus = 'linie'; _beidseitigAktiv = false; }); },
                  ),
                  ChoiceChip(
                    label: const Text('+ Text / Notiz'),
                    selected: _aktiverModus == 'text',
                    onSelected: (val) { setState(() => _aktiverModus = 'text'); },
                  ),
                  ChoiceChip(
                    label: const Text('🗑️ Einzeln löschen'),
                    selected: _aktiverModus == 'loeschen',
                    selectedColor: Colors.red.shade200,
                    onSelected: (val) { setState(() => _aktiverModus = 'loeschen'); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _aktiverModus == 'linie' 
                    ? (_beidseitigAktiv ? 'Modus: Beidseitige Maßlinie ziehen' : 'Modus: Einseitige Maßlinie (Tiefe) ziehen')
                    : (_aktiverModus == 'text' ? 'Modus: Klicke auf das Bild, um Text zu platzieren' : 'Modus: Klicke auf ein Element zum Löschen'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, 
                  color: _aktiverModus == 'loeschen' ? Colors.red : Colors.blueAccent, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: Container(
                  height: 480,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: _aktiverModus == 'loeschen' ? Colors.red : Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: GestureDetector(
                      onTapDown: (details) {
                        if (_aktiverModus == 'text') {
                          _textHinzufuegenDialog(details.localPosition);
                        } else if (_aktiverModus == 'loeschen') {
                          _elementAntippenZumLoeschen(details.localPosition);
                        }
                      },
                      onPanStart: (details) {
                        if (_aktiverModus == 'linie') {
                          setState(() {
                            _drawingStart = details.localPosition;
                            _drawingCurrent = details.localPosition;
                          });
                        }
                      },
                      onPanUpdate: (details) {
                        if (_aktiverModus == 'linie') {
                          setState(() {
                            _drawingCurrent = details.localPosition;
                          });
                        }
                      },
                      onPanEnd: (details) {
                        if (_aktiverModus == 'linie' && _drawingStart != null && _drawingCurrent != null) {
                          final start = _drawingStart!;
                          final end = _drawingCurrent!;
                          final beidseitig = _beidseitigAktiv;

                          setState(() {
                            _drawingStart = null;
                            _drawingCurrent = null;
                          });

                          _masseingabeDialog(start, end, beidseitig);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          kIsWeb
                              ? Image.network(_selectedImage!.path, fit: BoxFit.contain)
                              : Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
                          
                          CustomPaint(
                            painter: MassPainter(
                              linien: _linien,
                              textElemente: _textElemente,
                              standortText: _standortInfo,
                              drawingStart: _drawingStart,
                              drawingCurrent: _drawingCurrent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() { _linien.clear(); _textElemente.clear(); }),
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    label: const Text('Komplett zurücksetzen', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Noch kein Aufmass-Foto ausgewählt.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Aufmass speichern'),
            ),
          ],
        ),
      ),
    );
  }
}

class MassPainter extends CustomPainter {
  final List<MassLinie> linien;
  final List<PlaziertesTextElement> textElemente;
  final String standortText;
  final Offset? drawingStart;
  final Offset? drawingCurrent;

  MassPainter({
    required this.linien,
    required this.textElemente,
    required this.standortText,
    this.drawingStart,
    this.drawingCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final paintHead = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Standort unten links direkt auf das Bild eingebrannt
    if (standortText.isNotEmpty) {
      final textSpan = TextSpan(
        text: ' 📍 $standortText ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final double posX = 10;
      final double posY = size.height - textPainter.height - 15;

      final bgRect = Rect.fromLTWH(posX, posY, textPainter.width + 8, textPainter.height + 6);
      final bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), bgPaint);
      textPainter.paint(canvas, Offset(posX + 4, posY + 3));
    }

    for (var linie in linien) {
      _drawArrowWithText(canvas, linie.start, linie.end, linie.beidseitigerPfeil, linie.wert, paintLine, paintHead);
    }

    if (drawingStart != null && drawingCurrent != null) {
      _drawArrow(canvas, drawingStart!, drawingCurrent!, true, paintLine, paintHead);
    }

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    for (var item in textElemente) {
      _drawTextBox(canvas, item.text, item.position, bgPaint, Colors.yellow);
    }
  }

  void _drawArrowWithText(Canvas canvas, Offset p1, Offset p2, bool beidseitig, String text, Paint paintLine, Paint paintHead) {
    canvas.drawLine(p1, p2, paintLine);
    _drawArrowHead(canvas, p1, p2, paintHead);
    if (beidseitig) {
      _drawArrowHead(canvas, p2, p1, paintHead);
    }

    if (text.isNotEmpty) {
      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final textSpan = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final rect = Rect.fromLTWH(
        midPoint.dx - (textPainter.width / 2) - 4,
        midPoint.dy - (textPainter.height / 2) - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      final bgPaint = Paint()
        ..color = Colors.red.shade900.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, bgPaint);
      textPainter.paint(canvas, Offset(midPoint.dx - (textPainter.width / 2), midPoint.dy - (textPainter.height / 2)));
    }
  }

  void _drawArrow(Canvas canvas, Offset p1, Offset p2, bool beidseitig, Paint paintLine, Paint paintHead) {
    canvas.drawLine(p1, p2, paintLine);
    _drawArrowHead(canvas, p1, p2, paintHead);
    if (beidseitig) {
      _drawArrowHead(canvas, p2, p1, paintHead);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paintHead) {
    canvas.save();
    canvas.translate(to.dx, to.dy);
    canvas.rotate((to - from).direction);
    
    final arrowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-12, 6)
      ..lineTo(-12, -6)
      ..close();
      
    canvas.drawPath(arrowPath, paintHead);
    canvas.restore();
  }

  void _drawTextBox(Canvas canvas, String text, Offset position, Paint bgPaint, Color textColor) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final rect = Rect.fromLTWH(
      position.dx - 2,
      position.dy - 2,
      textPainter.width + 4,
      textPainter.height + 4,
    );
    canvas.drawRect(rect, bgPaint);
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}