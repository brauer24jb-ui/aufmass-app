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
import 'dart:ui' as ui;

// Globale Liste für die verfügbaren Kameras
List<CameraDescription> cameras = [];

// ==========================================
// SPRACH-STEUERUNG UND ÜBERSETZUNGEN
// ==========================================
enum AppLang { ruDe, ukDe, ruUk, de }
AppLang globalAppLang = AppLang.ruDe;

class Term {
  final String ru;
  final String uk;
  final String de;

  const Term({required this.ru, required this.uk, required this.de});

  String get display {
    switch (globalAppLang) {
      case AppLang.ruDe: return '$ru ($de)';
      case AppLang.ukDe: return '$uk ($de)';
      case AppLang.ruUk: return '$ru ($uk)';
      case AppLang.de: return de;
    }
  }

  String get value {
    switch (globalAppLang) {
      case AppLang.ruDe: return de;
      case AppLang.ukDe: return de;
      case AppLang.ruUk: return uk;
      case AppLang.de: return de;
    }
  }
}

// Werkzeuge / Menüs
final Map<String, Term> toolTerms = {
  'Länge': const Term(ru: 'Длина', uk: 'Довжина', de: 'Länge'),
  'Breite': const Term(ru: 'Ширина', uk: 'Ширина', de: 'Breite'),
  'Tiefe': const Term(ru: 'Глубина', uk: 'Глибина', de: 'Tiefe'),
  'Notiz 1': const Term(ru: '1. Заметка', uk: '1. Нотатка', de: '1. Notiz'),
  'Notiz 2': const Term(ru: '2. Заметка', uk: '2. Нотатка', de: '2. Notiz'),
  'Notiz 3': const Term(ru: '3. Заметка', uk: '3. Нотатка', de: '3. Notiz'),
  'Standort': const Term(ru: 'Адрес', uk: 'Адреса', de: 'Standort'),
};

// 1. Versorger
final List<Term> versorgerTerms = [
  const Term(ru: 'Вода', uk: 'Вода', de: 'Wasser'),
  const Term(ru: 'Газ', uk: 'Газ', de: 'Gas'),
  const Term(ru: 'Электричество', uk: 'Електрика', de: 'Strom'),
];

// 2. Material
final List<Term> materialTerms = [
  const Term(ru: 'Асфальт', uk: 'Асфальт', de: 'Asphalt'),
  const Term(ru: 'Бетонная плитка', uk: 'Бетонна плитка', de: 'Betonsteinpflaster'),
  const Term(ru: 'Бетонный щебень', uk: 'Бетонний щебінь', de: 'Betonschotter'),
  const Term(ru: 'Бордюр', uk: 'Бордюр', de: 'Bordstein'),
  const Term(ru: 'Дробленый песок', uk: 'Дроблений пісок', de: 'Brechsand'),
  const Term(ru: 'Грунт', uk: 'Ґрунт', de: 'Boden'),
  const Term(ru: 'Кабель', uk: 'Кабель', de: 'Kabel'),
  const Term(ru: 'Клинкер', uk: 'Клінкер', de: 'Klinkerpflaster'),
  const Term(ru: 'Колодец', uk: 'Колодязь', de: 'Schacht'),
  const Term(ru: 'Лоток', uk: 'Жолоб', de: 'Rinne'),
  const Term(ru: 'Минеральная смесь', uk: 'Мінеральна суміш', de: 'Mineralgemisch'),
  const Term(ru: 'Трубы KG', uk: 'Труби KG', de: 'KG Rohre'),
  const Term(ru: 'Трубы KG 2000', uk: 'Труби KG 2000', de: 'KG 2000 Rohre'),
  const Term(ru: 'Узловая брусчатка', uk: 'Замкова бруківка', de: 'Verbundsteinpflaster'),
  const Term(ru: 'Засыпной песок', uk: 'Засипний пісок', de: 'Füllsand'),
];

// 3. Tätigkeit
final List<Term> taetigkeitTerms = [
  const Term(ru: 'Установлено', uk: 'Встановлено', de: 'gesetzt'),
  const Term(ru: 'Экскаватор', uk: 'Екскаватор', de: 'Bagger'),
  const Term(ru: 'Погрузчик', uk: 'Навантажувач', de: 'Radlader'),
  const Term(ru: 'Насос', uk: 'Насос', de: 'Pumpe'),
  const Term(ru: 'Часы', uk: 'Години', de: 'Stunden'),
  const Term(ru: 'Демонтировано', uk: 'Демонтовано', de: 'aufgenommen'),
  const Term(ru: 'Колодец/Яма', uk: 'Котлован/Яма', de: 'Grube'),
  const Term(ru: 'Почасовая оплата', uk: 'Погодинна оплата', de: 'Stundenlohn'),
  const Term(ru: 'Траншея', uk: 'Траншея', de: 'Graben'),
  const Term(ru: 'Уложено', uk: 'Покладено', de: 'verlegt'),
  const Term(ru: 'Шурф', uk: 'Шурф', de: 'Suchschachtung'),
];

final Term backTerm = const Term(ru: 'Назад', uk: 'Назад', de: 'Zurück');

// Übersetzungen der restlichen UI
String get uiStartTitle {
  if (globalAppLang == AppLang.ukDe) return 'Заміри на будівництві';
  if (globalAppLang == AppLang.de) return 'Aufmaß Baustelle';
  return 'Замеры на стройке';
}
String get uiLiveLocation {
  if (globalAppLang == AppLang.ukDe) return 'Поточна адреса (Live-Standort):';
  if (globalAppLang == AppLang.de) return 'Aktueller Standort (Live):';
  return 'Текущий адрес (Live-Standort):';
}