import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(const AufmassApp());
}

class AufmassApp extends StatelessWidget {
  const AufmassApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aufmaß JB',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const AufmassStartbildschirm(),
    );
  }
}

class AufmassStartbildschirm extends StatefulWidget {
  const AufmassStartbildschirm({Key? key}) : super(key: key);

  @override
  State<AufmassStartbildschirm> createState() => _AufmassStartbildschirmState();
}

class _AufmassStartbildschirmState extends State<AufmassStartbildschirm> {
  String _aktuelleAdresse = "Noch kein Standort ermittelt";
  String _koordinaten = "";
  bool _laedt = false;

  // Hauptfunktion zum Abrufen von GPS und Adresse
  Future<void> _standortAbrufenUndUebersetzen() async {
    setState(() {
      _laedt = true;
      _aktuelleAdresse = "Standort wird gesucht...";
      _koordinaten = "";
    });

    try {
      // 1. Prüfen, ob die App auf das GPS zugreifen darf
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _aktuelleAdresse = "Standort-Berechtigung verweigert.";
            _laedt = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _aktuelleAdresse = "Standort-Berechtigung dauerhaft blockiert.";
          _laedt = false;
        });
        return;
      }

      // 2. GPS Koordinaten holen
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _koordinaten = "Lat: ${position.latitude}, Lon: ${position.longitude}";
      });

      // 3. Koordinaten in echte Adresse übersetzen (Reverse Geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark ort = placemarks.first;
        setState(() {
          // Setzt die Adresse zusammen
          _aktuelleAdresse = "${ort.thoroughfare ?? ''} ${ort.subThoroughfare ?? ''}\n${ort.postalCode ?? ''} ${ort.locality ?? ''}";
        });
      }
    } catch (e) {
      setState(() {
        _aktuelleAdresse = "Fehler bei der Adressermittlung.";
      });
      print("Geocoding Fehler: $e");
    } finally {
      setState(() {
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neues Aufmaß anlegen'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 60, color: Colors.blueGrey),
              const SizedBox(height: 20),
              
              // Anzeige der ermittelten Adresse
              Text(
                _aktuelleAdresse,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Anzeige der reinen GPS-Zahlen (kleiner darunter)
              Text(
                _koordinaten,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // Button für die Adresse
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _laedt ? null : _standortAbrufenUndUebersetzen,
                  icon: _laedt 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.gps_fixed),
                  label: Text(_laedt ? "Ermittle Daten..." : "GPS & Adresse abrufen"),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Button für die Kamera
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    print("Kamera wird gestartet");
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Beweisfoto aufnehmen"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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