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
import 'dart:async'; 

// Globale Liste für die verfügbaren Kameras
List<CameraDescription> cameras = [];

// ==========================================
// SPRACH-STEUERUNG UND ÜBERSETZUNGEN
// ==========================================
enum AppLang { ruDe, ukDe, ruUk, de }
AppLang globalAppLang = AppLang.ukDe;

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

  String get dropdownLabel {
    switch (globalAppLang) {
      case AppLang.ruDe: return '$ru  ➔  $de';
      case AppLang.ukDe: return '$uk  ➔  $de';
      case AppLang.ruUk: return '$ru  ➔  $uk';
      case AppLang.de: return de;
    }
  }

  String get sourceLang {
    switch (globalAppLang) {
      case AppLang.ruDe: return ru;
      case AppLang.ukDe: return uk;
      case AppLang.ruUk: return ru;
      case AppLang.de: return de;
    }
  }

  String get outputLang {
    switch (globalAppLang) {
      case AppLang.ruDe: return de;
      case AppLang.ukDe: return de;
      case AppLang.ruUk: return uk;
      case AppLang.de: return de;
    }
  }

  String get value => outputLang;
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

// ==========================================
// 1. DROPDOWN: VERSORGER
// ==========================================
final List<Term> versorgerTerms = [
  const Term(ru: 'Вода', uk: 'Вода', de: 'Wasser'),
  const Term(ru: 'Газ', uk: 'Газ', de: 'Gas'),
  const Term(ru: 'Электричество', uk: 'Електрика', de: 'Strom'),
  const Term(ru: 'Телекоммуникации', uk: 'Телекомунікації', de: 'Telekom'),
  const Term(ru: 'Оптоволокно', uk: 'Оптоволокно', de: 'Glasfaser'),
  const Term(ru: 'Канализация', uk: 'Каналізація', de: 'Abwasser'),
  const Term(ru: 'Дождевая вода', uk: 'Дощова вода', de: 'Regenwasser'),
  const Term(ru: 'Смешанная вода', uk: 'Змішана вода', de: 'Mischwasser'),
  const Term(ru: 'Дренаж', uk: 'Дренаж', de: 'Drainage'),
  const Term(ru: 'Освещение', uk: 'Освітлення', de: 'Beleuchtung'),
];

// ==========================================
// 2. DROPDOWN: MATERIAL
// ==========================================
final List<Term> materialTerms = [
  const Term(ru: 'Асфальт', uk: 'Асфальт', de: 'Asphalt'),
  const Term(ru: 'Бетонная плитка', uk: 'Бетонна плитка', de: 'Betonsteinpflaster'),
  const Term(ru: 'Природный камень', uk: 'Природний камінь', de: 'Natursteinpflaster'),
  const Term(ru: 'Клинкер', uk: 'Клінкер', de: 'Klinkerpflaster'),
  const Term(ru: 'Гранитная брусчатка', uk: 'Гранітна бруківка', de: 'Granitkleinpflaster'),
  const Term(ru: 'Узловая брусчатка', uk: 'Замкова бруківка', de: 'Verbundsteinpflaster'),
  const Term(ru: 'Бордюр', uk: 'Бордюр', de: 'Bordstein'),
  const Term(ru: 'Поребрик', uk: 'Поребрик', de: 'Tiefbord'),
  const Term(ru: 'Лоток', uk: 'Жолоб', de: 'Rinne'),
  const Term(ru: 'Колодец', uk: 'Колодязь', de: 'Schacht'),
  const Term(ru: 'Г-образный камень', uk: 'Г-подібний блок', de: 'L-Stein / Winkelstütze'),
  const Term(ru: 'Трубы KG', uk: 'Труби KG', de: 'KG Rohre'),
  const Term(ru: 'Трубы KG 2000', uk: 'Труби KG 2000', de: 'KG 2000 Rohre'),
  const Term(ru: 'Бетонный щебень', uk: 'Бетонний щебінь', de: 'Betonschotter'),
  const Term(ru: 'Природный щебень', uk: 'Природний щебінь', de: 'Naturschotter'),
  const Term(ru: 'Минеральная смесь', uk: 'Мінеральна суміш', de: 'Mineralgemisch'),
  const Term(ru: 'Дробленый песок', uk: 'Дроблений пісок', de: 'Brechsand'),
  const Term(ru: 'Засыпной песок', uk: 'Засипний пісок', de: 'Füllsand'),
  const Term(ru: 'Сплит', uk: 'Спліт', de: 'Splitt'),
  const Term(ru: 'Грунт', uk: 'Ґрунт', de: 'Boden'),
  const Term(ru: 'Чернозем', uk: 'Чорнозем', de: 'Mutterboden / Oberboden'),
];

// ==========================================
// 3. DROPDOWN: TÄTIGKEIT
// ==========================================
final List<Term> taetigkeitTerms = [
  const Term(ru: 'Установлено', uk: 'Встановлено', de: 'gesetzt'),
  const Term(ru: 'Уложено', uk: 'Покладено', de: 'verlegt'),
  const Term(ru: 'Забетонировано', uk: 'Забетоновано', de: 'betoniert'),
  const Term(ru: 'Заасфальтировано', uk: 'Заасфальтовано', de: 'asphaltiert'),
  const Term(ru: 'Уплотнено', uk: 'Ущільнено', de: 'verdichtet'),
  const Term(ru: 'Отфрезеровано', uk: 'Відфрезеровано', de: 'gefräst'),
  const Term(ru: 'Отрезано', uk: 'Відрізано', de: 'geschnitten'),
  const Term(ru: 'Демонтировано', uk: 'Демонтовано', de: 'aufgenommen'),
  const Term(ru: 'Выемка грунта', uk: 'Виїмка ґрунту', de: 'Aushub'),
  const Term(ru: 'Траншея', uk: 'Траншея', de: 'Graben'),
  const Term(ru: 'Колодец/Яма', uk: 'Котлован/Яма', de: 'Baugrube'),
  const Term(ru: 'Шурф', uk: 'Шурф', de: 'Suchschlitz / Suchschachtung'),
  const Term(ru: 'Экскаватор', uk: 'Екскаватор', de: 'Bagger'),
  const Term(ru: 'Погрузчик', uk: 'Навантажувач', de: 'Radlader'),
  const Term(ru: 'Часы', uk: 'Години', de: 'Stunden'),
  const Term(ru: 'Почасовая оплата', uk: 'Погодинна оплата', de: 'Stundenlohn'),
];

// ==========================================
// 4. MAXIMAL ERWEITERTES MEGA-WÖRTERBUCH (UNSICHTBAR IM UI)
// INKLUSIVE ALLTAGSWÖRTER
// ==========================================
final List<Term> megaDictionaryTerms = [
  // --- VERMESSUNG & HIGHTECH ---
  const Term(ru: 'RTK-ГНСС', uk: 'RTK-ГНСС', de: 'RTK-GNSS'),
  const Term(ru: 'ГНСС', uk: 'ГНСС', de: 'GNSS'),
  const Term(ru: 'ГПС ровер', uk: 'ДПС ровер', de: 'GPS-Rover'),
  const Term(ru: 'Измерительная веха', uk: 'Вимірювальна віха', de: 'Messstab'),
  const Term(ru: 'Измерительный шест', uk: 'Вимірювальна жердина', de: 'Messstab'),
  const Term(ru: 'Координаты', uk: 'Координати', de: 'Koordinaten'),
  const Term(ru: 'Отметка', uk: 'Позначка', de: 'Höhenkote'),
  const Term(ru: 'Уровень моря', uk: 'Рівень моря', de: 'NN-Höhe'),
  const Term(ru: 'Разметка', uk: 'Розмітка', de: 'Absteckung'),
  const Term(ru: 'Нивелир', uk: 'Нівелір', de: 'Nivelliergerät'),
  const Term(ru: 'Лазер', uk: 'Лазер', de: 'Baulaser'),
  const Term(ru: 'Рулетка', uk: 'Рулетка', de: 'Maßband'),
  const Term(ru: 'Смета', uk: 'Кошторис', de: 'Kostenvoranschlag'),
  const Term(ru: 'Замер', uk: 'Замір', de: 'Aufmaß'),
  const Term(ru: 'Измерение', uk: 'Вимірювання', de: 'Aufmaß'),
  const Term(ru: 'Тендер', uk: 'Тендер', de: 'Ausschreibung'),

  // --- MASCHINEN & GERÄTE ---
  const Term(ru: 'Мини-экскаватор', uk: 'Міні-екскаватор', de: 'Minibagger'),
  const Term(ru: 'Миниэкскаватор', uk: 'Мініекскаватор', de: 'Minibagger'),
  const Term(ru: 'Экскаватор', uk: 'Екскаватор', de: 'Bagger'),
  const Term(ru: 'Ковш', uk: 'Ківш', de: 'Baggerschaufel / Löffel'),
  const Term(ru: 'Планировочный ковш', uk: 'Планувальний ківш', de: 'Grabenräumlöffel'),
  const Term(ru: 'Погрузчик', uk: 'Навантажувач', de: 'Radlader'),
  const Term(ru: 'Фронтальный погрузчик', uk: 'Фронтальний навантажувач', de: 'Radlader'),
  const Term(ru: 'Трактор', uk: 'Трактор', de: 'Traktor'),
  const Term(ru: 'Виброплита', uk: 'Віброплита', de: 'Rüttelplatte'),
  const Term(ru: 'Вибротрамбовка', uk: 'Вібротрамбовка', de: 'Stampfer / Frosch'),
  const Term(ru: 'Трамбовка', uk: 'Трамбовка', de: 'Stampfer'),
  const Term(ru: 'Каток', uk: 'Коток', de: 'Walze'),
  const Term(ru: 'Асфальтоукладчик', uk: 'Асфальтоукладальник', de: 'Asphaltfertiger'),
  const Term(ru: 'Грузовик', uk: 'Вантажівка', de: 'LKW'),
  const Term(ru: 'Самосвал', uk: 'Самоскид', de: 'Kipper'),
  const Term(ru: 'Прицеп', uk: 'Причіп', de: 'Anhänger'),
  const Term(ru: 'Кран', uk: 'Кран', de: 'Kran'),
  const Term(ru: 'Компрессор', uk: 'Компресор', de: 'Kompressor'),
  const Term(ru: 'Думпер', uk: 'Думпер', de: 'Dumper'),
  const Term(ru: 'Генератор', uk: 'Генератор', de: 'Stromaggregat'),
  const Term(ru: 'Насос', uk: 'Насос', de: 'Pumpe'),
  
  // --- WERKZEUG ---
  const Term(ru: 'Лопата', uk: 'Лопата', de: 'Schaufel'),
  const Term(ru: 'Стыковая лопата', uk: 'Штикова лопата', de: 'Spaten'),
  const Term(ru: 'Метла', uk: 'Мітла', de: 'Besen'),
  const Term(ru: 'Щетка', uk: 'Щітка', de: 'Bürste'),
  const Term(ru: 'Молоток', uk: 'Молоток', de: 'Hammer'),
  const Term(ru: 'Резиновый молоток', uk: 'Гумовий молоток', de: 'Gummihammer'),
  const Term(ru: 'Кувалда', uk: 'Кувалда', de: 'Vorschlaghammer'),
  const Term(ru: 'Болгарка', uk: 'Болгарка', de: 'Flex / Trennschleifer'),
  const Term(ru: 'Диск', uk: 'Диск', de: 'Trennscheibe'),
  const Term(ru: 'Пила', uk: 'Пила', de: 'Säge'),
  const Term(ru: 'Бензорез', uk: 'Бензоріз', de: 'Motorflex / Fugenschneider'),
  const Term(ru: 'Бензопила', uk: 'Бензопила', de: 'Kettensäge'),
  const Term(ru: 'Дрель', uk: 'Дриль', de: 'Bohrmaschine'),
  const Term(ru: 'Перфоратор', uk: 'Перфоратор', de: 'Bohrhammer'),
  const Term(ru: 'Уровень', uk: 'Рівень', de: 'Wasserwaage'),
  const Term(ru: 'Кельма', uk: 'Кельма', de: 'Kelle'),
  const Term(ru: 'Мастерок', uk: 'Майстерок', de: 'Kelle'),
  const Term(ru: 'Тачка', uk: 'Тачка', de: 'Schubkarre'),
  const Term(ru: 'Ведро', uk: 'Відро', de: 'Eimer'),
  const Term(ru: 'Лом', uk: 'Брухт / Лом', de: 'Brechstange'),
  
  // --- MATERIALIEN & BAUTEILE (Pflaster, Straßenbau) ---
  const Term(ru: 'Клинкерная брусчатка', uk: 'Клінкерна бруківка', de: 'Klinkerpflaster'),
  const Term(ru: 'Гранитная брусчатка', uk: 'Гранітна бруківка', de: 'Granitkleinpflaster'),
  const Term(ru: 'Гранит', uk: 'Граніт', de: 'Granit'),
  const Term(ru: 'Тротуарная плитка', uk: 'Тротуарна плитка', de: 'Gehwegplatte'),
  const Term(ru: 'Бордюрный камень', uk: 'Бордюрний камінь', de: 'Bordstein'),
  const Term(ru: 'Поребрик', uk: 'Поребрик', de: 'Tiefbord / Kantenstein'),
  const Term(ru: 'Водоотводный желоб', uk: 'Водовідвідний жолоб', de: 'Entwässerungsrinne'),
  const Term(ru: 'Желоб', uk: 'Жолоб', de: 'Rinne'),
  const Term(ru: 'Подпорная стена', uk: 'Підпірна стіна', de: 'Stützmauer / Winkelstützwand'),
  const Term(ru: 'Бетон', uk: 'Бетон', de: 'Beton'),
  const Term(ru: 'Тощий бетон', uk: 'Пісний бетон', de: 'Magerbeton'),
  const Term(ru: 'Цемент', uk: 'Цемент', de: 'Zement'),
  const Term(ru: 'Раствор', uk: 'Розчин', de: 'Mörtel'),
  const Term(ru: 'Щебень', uk: 'Щебінь', de: 'Schotter'),
  const Term(ru: 'Гравий', uk: 'Гравій', de: 'Kies'),
  const Term(ru: 'Песок', uk: 'Пісок', de: 'Sand'),
  const Term(ru: 'Смесь', uk: 'Суміш', de: 'Gemisch'),
  const Term(ru: 'Галька', uk: 'Галька', de: 'Kiesel'),
  const Term(ru: 'Земля', uk: 'Земля', de: 'Erde'),
  const Term(ru: 'Глина', uk: 'Глина', de: 'Lehm / Ton'),
  const Term(ru: 'Грязь', uk: 'Бруд', de: 'Schlamm'),
  const Term(ru: 'Мусор', uk: 'Сміття', de: 'Bauschutt'),
  const Term(ru: 'Камень', uk: 'Камінь', de: 'Stein'),
  const Term(ru: 'Камни', uk: 'Камені', de: 'Steine'),
  const Term(ru: 'Плитка', uk: 'Плитка', de: 'Platten'),
  const Term(ru: 'Брусчатка', uk: 'Бруківка', de: 'Pflaster'),
  
  // --- ROHRLEITUNGS- & TIEFBAU ---
  const Term(ru: 'Газопровод', uk: 'Газопровід', de: 'Gasleitung'),
  const Term(ru: 'Водопровод', uk: 'Водопровід', de: 'Wasserleitung'),
  const Term(ru: 'Очистные сооружения', uk: 'Очисні споруди', de: 'Kläranlage'),
  const Term(ru: 'Труба', uk: 'Труба', de: 'Rohr'),
  const Term(ru: 'Трубы', uk: 'Труби', de: 'Rohre'),
  const Term(ru: 'ПВХ', uk: 'ПВХ', de: 'PVC'),
  const Term(ru: 'Провод', uk: 'Провід', de: 'Leitung'),
  const Term(ru: 'Шланг', uk: 'Шланг', de: 'Schlauch'),
  const Term(ru: 'Муфта', uk: 'Муфта', de: 'Muffe'),
  const Term(ru: 'Отвод', uk: 'Відвід', de: 'Bogen / Abzweig'),
  const Term(ru: 'Уплотнитель', uk: 'Ущільнювач', de: 'Dichtung'),
  const Term(ru: 'Крышка', uk: 'Кришка', de: 'Deckel'),
  const Term(ru: 'Люк', uk: 'Люк', de: 'Schachtdeckel'),
  const Term(ru: 'Конус', uk: 'Конус', de: 'Schachtkonus'),
  const Term(ru: 'Кольцо', uk: 'Кільце', de: 'Schachtring'),
  const Term(ru: 'Дно', uk: 'Дно', de: 'Schachtboden'),
  const Term(ru: 'Сток', uk: 'Стік', de: 'Ablauf / Gulli'),
  const Term(ru: 'Решетка', uk: 'Решітка', de: 'Gitter / Rost'),
  const Term(ru: 'Пленка', uk: 'Плівка', de: 'Folie'),
  const Term(ru: 'Геотекстиль', uk: 'Геотекстиль', de: 'Vlies'),
  const Term(ru: 'Изоляция', uk: 'Ізоляція', de: 'Isolierung'),
  const Term(ru: 'Битум', uk: 'Бітум', de: 'Bitumen'),
  const Term(ru: 'Дерево', uk: 'Дерево', de: 'Holz'),
  const Term(ru: 'Доска', uk: 'Дошка', de: 'Brett'),
  const Term(ru: 'Брус', uk: 'Брус', de: 'Balken'),
  const Term(ru: 'Сталь', uk: 'Сталь', de: 'Stahl'),
  const Term(ru: 'Арматура', uk: 'Арматура', de: 'Bewehrung'),
  const Term(ru: 'Сетка', uk: 'Сітка', de: 'Baustahlmatte'),
  
  // --- STRUKTUREN & KONSTRUKTIONEN ---
  const Term(ru: 'Защитный слой от мороза', uk: 'Морозозахисний шар', de: 'Frostschutzschicht'),
  const Term(ru: 'Несущий слой', uk: 'Несучий шар', de: 'Tragschicht'),
  const Term(ru: 'Верхний слой', uk: 'Верхній шар', de: 'Deckschicht'),
  const Term(ru: 'Планум', uk: 'Планум', de: 'Planum'),
  const Term(ru: 'Постель', uk: 'Постіль', de: 'Bettung / Pflasterbett'),
  const Term(ru: 'Тротуар', uk: 'Тротуар', de: 'Gehweg'),
  const Term(ru: 'Дорога', uk: 'Дорога', de: 'Fahrbahn'),
  const Term(ru: 'Улица', uk: 'Вулиця', de: 'Straße'),
  const Term(ru: 'Перекресток', uk: 'Перехрестя', de: 'Kreuzung'),
  const Term(ru: 'Парковка', uk: 'Парковка', de: 'Parkplatz'),
  const Term(ru: 'Въезд', uk: 'В\'їзд', de: 'Einfahrt'),
  const Term(ru: 'Ограждение', uk: 'Огорожа', de: 'Absperrung'),
  const Term(ru: 'Забор', uk: 'Паркан', de: 'Zaun'),
  const Term(ru: 'Колышек', uk: 'Кілочок', de: 'Pflock'),
  const Term(ru: 'Ямочный ремонт', uk: 'Ямковий ремонт', de: 'Schlaglochflickung'),
  const Term(ru: 'Крепление траншеи', uk: 'Кріплення траншеї', de: 'Grabenverbau'),
  const Term(ru: 'Шпунтовое ограждение', uk: 'Шпунтова огорожа', de: 'Spundwand'),
  const Term(ru: 'Стена', uk: 'Стіна', de: 'Wand / Mauer'),
  const Term(ru: 'Фундамент', uk: 'Фундамент', de: 'Fundament'),
  const Term(ru: 'Ступенька', uk: 'Сходинка', de: 'Stufe'),
  const Term(ru: 'Лестница', uk: 'Сходи', de: 'Treppe'),
  const Term(ru: 'Опалубка', uk: 'Опалубка', de: 'Schalung'),
  const Term(ru: 'Скважина', uk: 'Свердловина', de: 'Bohrung / Brunnen'),

  // --- GALABAU (Garten- & Landschaftsbau) ---
  const Term(ru: 'Газонокосилка', uk: 'Газонокосарка', de: 'Rasenmäher'),
  const Term(ru: 'Газон', uk: 'Газон', de: 'Rasen'),
  const Term(ru: 'Трава', uk: 'Трава', de: 'Gras'),
  const Term(ru: 'Почва', uk: 'Почва', de: 'Boden'),
  const Term(ru: 'Перегной', uk: 'Перегній', de: 'Humus'),
  const Term(ru: 'Мульча', uk: 'Мульча', de: 'Rindenmulch'),
  const Term(ru: 'Кора', uk: 'Кора', de: 'Rinde'),
  const Term(ru: 'Сорняк', uk: 'Бур\'ян', de: 'Unkraut'),
  const Term(ru: 'Растение', uk: 'Рослина', de: 'Pflanze'),
  const Term(ru: 'Куст', uk: 'Кущ', de: 'Strauch'),
  const Term(ru: 'Кустарник', uk: 'Чагарник', de: 'Gebüsch'),
  const Term(ru: 'Дерево', uk: 'Дерево', de: 'Baum'),
  const Term(ru: 'Деревья', uk: 'Дерева', de: 'Bäume'),
  const Term(ru: 'Корень', uk: 'Корінь', de: 'Wurzel'),
  const Term(ru: 'Корни', uk: 'Коріння', de: 'Wurzeln'),
  const Term(ru: 'Ветка', uk: 'Гілка', de: 'Ast'),
  const Term(ru: 'Ветки', uk: 'Гілки', de: 'Äste'),
  const Term(ru: 'Лист', uk: 'Лист', de: 'Blatt'),
  const Term(ru: 'Листья', uk: 'Листя', de: 'Laub'),
  const Term(ru: 'Живая изгородь', uk: 'Живопліт', de: 'Hecke'),
  const Term(ru: 'Терраса', uk: 'Тераса', de: 'Terrasse'),
  const Term(ru: 'Клумба', uk: 'Клумба', de: 'Beet'),
  const Term(ru: 'Пруд', uk: 'Ставок', de: 'Teich'),
  const Term(ru: 'Удобрение', uk: 'Добриво', de: 'Dünger'),
  const Term(ru: 'Полив', uk: 'Полив', de: 'Bewässerung'),
  const Term(ru: 'Семена', uk: 'Насіння', de: 'Saatgut'),
  
  // --- VERBEN / TÄTIGKEITEN (Baustelle) ---
  const Term(ru: 'Асфальтировали', uk: 'Асфальтували', de: 'asphaltiert'),
  const Term(ru: 'Заасфальтировали', uk: 'Заасфальтували', de: 'asphaltiert'),
  const Term(ru: 'Равняли', uk: 'Рівняли', de: 'planiert'),
  const Term(ru: 'Равнять', uk: 'Рівняти', de: 'planieren'),
  const Term(ru: 'Спланировали', uk: 'Спланували', de: 'planiert'),
  const Term(ru: 'Копали', uk: 'Копали', de: 'ausgehoben'),
  const Term(ru: 'Выкопали', uk: 'Викопали', de: 'ausgehoben'),
  const Term(ru: 'Аускофферн', uk: 'Вийняти ґрунт', de: 'ausgekoffert'), 
  const Term(ru: 'Копать', uk: 'Копати', de: 'baggern / graben'),
  const Term(ru: 'Засыпали', uk: 'Засипали', de: 'verfüllt'),
  const Term(ru: 'Засыпать', uk: 'Засипати', de: 'verfüllen'),
  const Term(ru: 'Утрамбовали', uk: 'Утрамбували', de: 'verdichtet'),
  const Term(ru: 'Уплотняли', uk: 'Ущільнювали', de: 'verdichtet'),
  const Term(ru: 'Трамбовали', uk: 'Трамбували', de: 'verdichtet'),
  const Term(ru: 'Резали', uk: 'Різали', de: 'geschnitten'),
  const Term(ru: 'Отрезали', uk: 'Відрізали', de: 'abgeschnitten'),
  const Term(ru: 'Пилили', uk: 'Пилили', de: 'geflext / gesägt'),
  const Term(ru: 'Уложили', uk: 'Поклали', de: 'verlegt'),
  const Term(ru: 'Положили', uk: 'Поклали', de: 'gelegt'),
  const Term(ru: 'Залили', uk: 'Залили', de: 'betoniert'),
  const Term(ru: 'Замостили', uk: 'Замостили', de: 'gepflastert'),
  const Term(ru: 'Затерли', uk: 'Затерли', de: 'verfugt / eingeschlämmt'),
  const Term(ru: 'Установили', uk: 'Встановили', de: 'gesetzt / montiert'),
  const Term(ru: 'Поставили', uk: 'Поставили', de: 'aufgestellt'),
  const Term(ru: 'Сломали', uk: 'Зламали', de: 'abgebrochen / zerstört'),
  const Term(ru: 'Разрушили', uk: 'Зруйнували', de: 'abgerissen'),
  const Term(ru: 'Демонтировали', uk: 'Демонтували', de: 'demontiert / rückgebaut'),
  const Term(ru: 'Сняли', uk: 'Зняли', de: 'ausgebaut / aufgenommen'),
  const Term(ru: 'Убрали', uk: 'Прибрали', de: 'weggeräumt'),
  const Term(ru: 'Перестроили', uk: 'Перебудували', de: 'umgebaut'),
  const Term(ru: 'Покрасили', uk: 'Фарбували', de: 'gestrichen'),
  const Term(ru: 'Починили', uk: 'Полагодили', de: 'repariert'),
  const Term(ru: 'Отремонтировали', uk: 'Відремонтували', de: 'repariert / erneuert'),
  const Term(ru: 'Проверили', uk: 'Перевірили', de: 'geprüft'),
  const Term(ru: 'Замерили', uk: 'Заміряли', de: 'eingemessen'),
  const Term(ru: 'Измерили', uk: 'Виміряли', de: 'gemessen'),
  const Term(ru: 'Отметили', uk: 'Відмітили', de: 'markiert / abgesteckt'),
  const Term(ru: 'Подключили', uk: 'Підключили', de: 'angeschlossen'),
  const Term(ru: 'Отключили', uk: 'Відключили', de: 'abgeklemmt'),
  const Term(ru: 'Очистили', uk: 'Очистили', de: 'gereinigt'),
  const Term(ru: 'Помыли', uk: 'Помили', de: 'gewaschen'),
  const Term(ru: 'Смели', uk: 'Змели', de: 'gefegt'),
  const Term(ru: 'Подмели', uk: 'Підмели', de: 'gefegt'),
  const Term(ru: 'Посадили', uk: 'Посадили', de: 'gepflanzt'),
  const Term(ru: 'Посеяли', uk: 'Посіяли', de: 'gesät'),
  const Term(ru: 'Полили', uk: 'Полили', de: 'gegossen'),
  const Term(ru: 'Привезли', uk: 'Привезли', de: 'geliefert'),
  const Term(ru: 'Увезли', uk: 'Повезли', de: 'abtransportiert'),

  // ==========================================
  // NEU: ALLTAGS- UND BASISWORTSCHATZ
  // ==========================================
  
  // --- VERBEN (Allgemein) ---
  const Term(ru: 'Делать', uk: 'Робити', de: 'machen'),
  const Term(ru: 'Сделали', uk: 'Зробили', de: 'gemacht'),
  const Term(ru: 'Работать', uk: 'Працювати', de: 'arbeiten'),
  const Term(ru: 'Работали', uk: 'Працювали', de: 'gearbeitet'),
  const Term(ru: 'Помогать', uk: 'Допомагати', de: 'helfen'),
  const Term(ru: 'Брать', uk: 'Брати', de: 'nehmen'),
  const Term(ru: 'Взяли', uk: 'Взяли', de: 'genommen'),
  const Term(ru: 'Давать', uk: 'Давати', de: 'geben'),
  const Term(ru: 'Дали', uk: 'Дали', de: 'gegeben'),
  const Term(ru: 'Нужно', uk: 'Потрібно', de: 'brauchen / benötigt'),
  const Term(ru: 'Искать', uk: 'Шукати', de: 'suchen'),
  const Term(ru: 'Нашли', uk: 'Знайшли', de: 'gefunden'),
  const Term(ru: 'Смотреть', uk: 'Дивитися', de: 'schauen'),
  const Term(ru: 'Видеть', uk: 'Бачити', de: 'sehen'),
  const Term(ru: 'Идти', uk: 'Йти', de: 'gehen'),
  const Term(ru: 'Пришли', uk: 'Прийшли', de: 'gekommen'),
  
  // --- ZUSTÄNDE, ADJEKTIVE & EIGENSCHAFTEN ---
  const Term(ru: 'Сломан', uk: 'Зламаний', de: 'defekt'),
  const Term(ru: 'Сломана', uk: 'Зламана', de: 'defekt'),
  const Term(ru: 'Сломано', uk: 'Зламано', de: 'defekt'),
  const Term(ru: 'Порван', uk: 'Порваний', de: 'gerissen'),
  const Term(ru: 'Новый', uk: 'Новий', de: 'neu'),
  const Term(ru: 'Новая', uk: 'Нова', de: 'neu'),
  const Term(ru: 'Старый', uk: 'Старий', de: 'alt'),
  const Term(ru: 'Старая', uk: 'Стара', de: 'alt'),
  const Term(ru: 'Хорошо', uk: 'Добре', de: 'gut'),
  const Term(ru: 'Плохо', uk: 'Погано', de: 'schlecht'),
  const Term(ru: 'Быстро', uk: 'Швидко', de: 'schnell'),
  const Term(ru: 'Медленно', uk: 'Повільно', de: 'langsam'),
  const Term(ru: 'Большой', uk: 'Великий', de: 'groß'),
  const Term(ru: 'Маленький', uk: 'Маленький', de: 'klein'),
  const Term(ru: 'Глубоко', uk: 'Глибоко', de: 'tief'),
  const Term(ru: 'Мелко', uk: 'Мілко', de: 'flach'),
  const Term(ru: 'Широко', uk: 'Широко', de: 'breit'),
  const Term(ru: 'Узко', uk: 'Вузько', de: 'schmal'),
  const Term(ru: 'Длинно', uk: 'Довго', de: 'lang'),
  const Term(ru: 'Коротко', uk: 'Коротко', de: 'kurz'),
  const Term(ru: 'Высоко', uk: 'Високо', de: 'hoch'),
  const Term(ru: 'Прямо', uk: 'Прямо', de: 'gerade'),
  const Term(ru: 'Криво', uk: 'Криво', de: 'schief'),
  const Term(ru: 'Точно', uk: 'Точно', de: 'exakt'),
  const Term(ru: 'Примерно', uk: 'Приблизно', de: 'ca.'),
  const Term(ru: 'Мокрый', uk: 'Мокрий', de: 'nass'),
  const Term(ru: 'Сухой', uk: 'Сухий', de: 'trocken'),
  const Term(ru: 'Чистый', uk: 'Чистий', de: 'sauber'),
  const Term(ru: 'Грязный', uk: 'Брудний', de: 'schmutzig'),
  const Term(ru: 'Тяжелый', uk: 'Важкий', de: 'schwer'),
  const Term(ru: 'Легкий', uk: 'Легкий', de: 'leicht'),
  const Term(ru: 'Готово', uk: 'Готово', de: 'fertig'),
  const Term(ru: 'Не готово', uk: 'Не готово', de: 'unfertig'),
  const Term(ru: 'Пусто', uk: 'Пусто', de: 'leer'),
  const Term(ru: 'Полный', uk: 'Повний', de: 'voll'),
  const Term(ru: 'Открыто', uk: 'Відкрито', de: 'offen'),
  const Term(ru: 'Закрыто', uk: 'Закрито', de: 'geschlossen'),
  
  // --- RICHTUNGEN & ORTE ---
  const Term(ru: 'Вверх', uk: 'Вгору', de: 'oben'),
  const Term(ru: 'Вниз', uk: 'Вниз', de: 'unten'),
  const Term(ru: 'Налево', uk: 'Наліво', de: 'links'),
  const Term(ru: 'Направо', uk: 'Направо', de: 'rechts'),
  const Term(ru: 'Вперед', uk: 'Вперед', de: 'vorne'),
  const Term(ru: 'Назад', uk: 'Назад', de: 'hinten'),
  const Term(ru: 'Здесь', uk: 'Тут', de: 'hier'),
  const Term(ru: 'Там', uk: 'Там', de: 'dort'),
  const Term(ru: 'Внутри', uk: 'Всередині', de: 'innen'),
  const Term(ru: 'Снаружи', uk: 'Зовні', de: 'außen'),
  
  // --- ZEIT & WETTER ---
  const Term(ru: 'Сегодня', uk: 'Сьогодні', de: 'heute'),
  const Term(ru: 'Завтра', uk: 'Завтра', de: 'morgen'),
  const Term(ru: 'Вчера', uk: 'Вчора', de: 'gestern'),
  const Term(ru: 'Утром', uk: 'Вранці', de: 'morgens / früh'),
  const Term(ru: 'Вечером', uk: 'Увечері', de: 'abends / spät'),
  const Term(ru: 'Понедельник', uk: 'Понеділок', de: 'Montag'),
  const Term(ru: 'Вторник', uk: 'Вівторок', de: 'Dienstag'),
  const Term(ru: 'Среда', uk: 'Середа', de: 'Mittwoch'),
  const Term(ru: 'Четверг', uk: 'Четвер', de: 'Donnerstag'),
  const Term(ru: 'Пятница', uk: 'П\'ятниця', de: 'Freitag'),
  const Term(ru: 'Суббота', uk: 'Субота', de: 'Samstag'),
  const Term(ru: 'Воскресенье', uk: 'Неділя', de: 'Sonntag'),
  const Term(ru: 'Погода', uk: 'Погода', de: 'Wetter'),
  const Term(ru: 'Дождь', uk: 'Дощ', de: 'Regen'),
  const Term(ru: 'Снег', uk: 'Сніг', de: 'Schnee'),
  const Term(ru: 'Солнце', uk: 'Сонце', de: 'Sonne'),
  const Term(ru: 'Ветер', uk: 'Вітер', de: 'Wind'),
  const Term(ru: 'Тепло', uk: 'Тепло', de: 'warm'),
  const Term(ru: 'Холодно', uk: 'Холодно', de: 'kalt'),
  
  // --- FARBEN ---
  const Term(ru: 'Красный', uk: 'Червоний', de: 'rot'),
  const Term(ru: 'Синий', uk: 'Синій', de: 'blau'),
  const Term(ru: 'Зеленый', uk: 'Зелений', de: 'grün'),
  const Term(ru: 'Желтый', uk: 'Жовтий', de: 'gelb'),
  const Term(ru: 'Черный', uk: 'Чорний', de: 'schwarz'),
  const Term(ru: 'Белый', uk: 'Білий', de: 'weiß'),
  const Term(ru: 'Серый', uk: 'Сірий', de: 'grau'),
  const Term(ru: 'Коричневый', uk: 'Коричневий', de: 'braun'),
  const Term(ru: 'Оранжевый', uk: 'Помаранчевий', de: 'orange'),

  // --- MENGEN & ZAHLEN ---
  const Term(ru: 'Один', uk: 'Один', de: 'eins'),
  const Term(ru: 'Два', uk: 'Два', de: 'zwei'),
  const Term(ru: 'Три', uk: 'Три', de: 'drei'),
  const Term(ru: 'Десять', uk: 'Десять', de: 'zehn'),
  const Term(ru: 'Много', uk: 'Багато', de: 'viel'),
  const Term(ru: 'Мало', uk: 'Мало', de: 'wenig'),
  const Term(ru: 'Больше', uk: 'Більше', de: 'mehr'),
  const Term(ru: 'Меньше', uk: 'Менше', de: 'weniger'),
  const Term(ru: 'Всё', uk: 'Все', de: 'alles'),
  const Term(ru: 'Ничего', uk: 'Нічого', de: 'nichts'),
  
  // --- EINHEITEN & ABKÜRZUNGEN ---
  const Term(ru: 'Квадратный метр', uk: 'Квадратний метр', de: 'Quadratmeter'),
  const Term(ru: 'Куб', uk: 'Куб', de: 'Kubikmeter'),
  const Term(ru: 'Метр', uk: 'Метр', de: 'Meter'),
  const Term(ru: 'Сантиметр', uk: 'Сантиметр', de: 'Zentimeter'),
  const Term(ru: 'Миллиметр', uk: 'Міліметр', de: 'Millimeter'),
  const Term(ru: 'Штука', uk: 'Штука', de: 'Stück'),
  const Term(ru: 'Штуки', uk: 'Штуки', de: 'Stück'),
  const Term(ru: 'Тонна', uk: 'Тонна', de: 'Tonne'),
  const Term(ru: 'Килограмм', uk: 'Кілограм', de: 'Kilogramm'),
  const Term(ru: 'Слой', uk: 'Шар', de: 'Schicht'),
  const Term(ru: 'Ряд', uk: 'Ряд', de: 'Reihe'),
  const Term(ru: 'Поддон', uk: 'Піддон', de: 'Palette'),
  const Term(ru: 'Палета', uk: 'Палета', de: 'Palette'),
];

// Zusammenfassung ALLER Wörter für den automatischen Live-Übersetzer
final List<Term> allDictionaryTerms = [
  ...versorgerTerms,
  ...materialTerms,
  ...taetigkeitTerms,
  ...megaDictionaryTerms,
];

final Term backTerm = const Term(ru: 'Назад', uk: 'Назад', de: 'Zurück');

// Übersetzungen der UI
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
String get uiRefresh {
  if (globalAppLang == AppLang.ukDe) return 'Оновити адресу';
  if (globalAppLang == AppLang.de) return 'Adresse aktualisieren';
  return 'Обновить адрес';
}
String get uiPhoto {
  if (globalAppLang == AppLang.ukDe) return 'Зробити фото';
  if (globalAppLang == AppLang.de) return 'Foto machen';
  return 'Сделать фото';
}
String get uiGallery {
  if (globalAppLang == AppLang.ukDe) return 'Вибрати з галереї';
  if (globalAppLang == AppLang.de) return 'Aus Galerie wählen';
  return 'Выбрать из галереи';
}
String get uiMode {
  if (globalAppLang == AppLang.de) return 'Modus:';
  if (globalAppLang == AppLang.ukDe) return 'Режим:';
  return 'Режим:';
}
String get uiData {
  if (globalAppLang == AppLang.ukDe) return 'Дані';
  if (globalAppLang == AppLang.de) return 'Daten';
  return 'Данные';
}
String get uiInputTitle {
  if (globalAppLang == AppLang.ukDe) return 'Введення даних (Maße & Notizen)';
  if (globalAppLang == AppLang.de) return 'Dateneingabe (Maße & Notizen)';
  return 'Ввод данных (Maße & Notizen)';
}
String get uiAcceptReturn {
  if (globalAppLang == AppLang.ukDe) return 'Прийняти та повернутися';
  if (globalAppLang == AppLang.de) return 'Übernehmen & Zurück';
  return 'Принять и вернуться';
}
String get uiAddress {
  if (globalAppLang == AppLang.ukDe) return 'Адреса / Об\'єкт';
  if (globalAppLang == AppLang.de) return 'Adresse / Objekt';
  return 'Адрес / Объект';
}
String get uiSaveToPhotos {
  if (globalAppLang == AppLang.ukDe) return 'Зберегти в фото';
  if (globalAppLang == AppLang.ruUk) return 'Сохранить в фото';
  if (globalAppLang == AppLang.de) return 'In Fotos speichern';
  return 'Сохранить в фото';
}
String get uiSavedSuccess {
  if (globalAppLang == AppLang.ukDe) return 'Збережено в фото!';
  if (globalAppLang == AppLang.ruUk) return 'Сохранено в фото!';
  if (globalAppLang == AppLang.de) return 'In Fotos gespeichert!';
  return 'Сохранено в фото!';
}

String get uiNote1 {
  if (globalAppLang == AppLang.ukDe) return '1. Примітка (1. Versorger)';
  if (globalAppLang == AppLang.ruUk) return '1. Заметка (1. Постачальник)';
  if (globalAppLang == AppLang.de) return '1. Notiz (Versorger)';
  return '1. Примечание (1. Auswahl Versorger)';
}
String get uiNote2 {
  if (globalAppLang == AppLang.ukDe) return '2. Примітка (2. Material)';
  if (globalAppLang == AppLang.ruUk) return '2. Заметка (2. Матеріал)';
  if (globalAppLang == AppLang.de) return '2. Notiz (Material)';
  return '2. Примечание (2. Material)';
}
String get uiNote3 {
  if (globalAppLang == AppLang.ukDe) return '3. Примітка (3. Tätigkeit)';
  if (globalAppLang == AppLang.ruUk) return '3. Заметка (3. Діяльність)';
  if (globalAppLang == AppLang.de) return '3. Notiz (Tätigkeit)';
  return '3. Примечание (3. Tätigkeit)';
}
String get uiSelect1 {
  if (globalAppLang == AppLang.ukDe) return '1. Вибір постачальника (1. Auswahl Versorger)';
  if (globalAppLang == AppLang.ruUk) return '1. Выбор поставщика (1. Постачальник)';
  if (globalAppLang == AppLang.de) return '1. Auswahl (Versorger)';
  return '1. Выбор поставщика (1. Auswahl Versorger)';
}
String get uiSelect2 {
  if (globalAppLang == AppLang.ukDe) return '2. Вибір матеріалу (2. Auswahl Material)';
  if (globalAppLang == AppLang.ruUk) return '2. Выбор материала (2. Матеріал)';
  if (globalAppLang == AppLang.de) return '2. Auswahl (Material)';
  return '2. Выбор материала (2. Auswahl Material)';
}
String get uiSelect3 {
  if (globalAppLang == AppLang.ukDe) return '3. Вибір діяльності (3. Auswahl Tätigkeit)';
  if (globalAppLang == AppLang.ruUk) return '3. Выбор діяльності (3. Діяльність)';
  if (globalAppLang == AppLang.de) return '3. Auswahl (Tätigkeit)';
  return '3. Выбор деятельности (3. Auswahl Tätigkeit)';
}
String get uiHint1 {
  if (globalAppLang == AppLang.ukDe) return 'Виберіть постачальника...';
  if (globalAppLang == AppLang.de) return 'Versorger wählen...';
  return 'Выберите постачальника...';
}
String get uiHint2 {
  if (globalAppLang == AppLang.ukDe) return 'Виберіть матеріал...';
  if (globalAppLang == AppLang.de) return 'Material wählen...';
  return 'Выберите материал...';
}
String get uiHint3 {
  if (globalAppLang == AppLang.ukDe) return 'Виберіть діяльність...';
  if (globalAppLang == AppLang.de) return 'Tätigkeit wählen...';
  return 'Выберите деятельность...';
}

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

      DateTime now = DateTime.now();
      String timeStr = "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} Uhr";
      
      String coordStr = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationMessage = "${place.street ?? ''}, ${place.postalCode ?? ''} ${place.locality ?? ''}\n$coordStr\n$timeStr";
          });
        } else {
          setState(() {
            _locationMessage = "Unbekannter Ort\n$coordStr\n$timeStr";
          });
        }
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
        title: Text(uiStartTitle),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<AppLang>(
              value: globalAppLang,
              icon: const Icon(Icons.language, color: Colors.white),
              dropdownColor: Colors.blue.shade100,
              onChanged: (AppLang? newValue) {
                if (newValue != null) {
                  setState(() {
                    globalAppLang = newValue;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: AppLang.ruDe, child: Text('RU -> DE', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: AppLang.ukDe, child: Text('UK -> DE', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: AppLang.ruUk, child: Text('RU -> UK', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: AppLang.de, child: Text('DE', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.location_pin, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                uiLiveLocation,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _locationMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey, height: 1.4),
              ),
              const SizedBox(height: 12),
              
              TextButton.icon(
                onPressed: _getLiveLocation,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(uiRefresh),
              ),

              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _openCustomCamera(context),
                  icon: const Icon(Icons.camera_alt, size: 28),
                  label: Text(uiPhoto, style: const TextStyle(fontSize: 18)),
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
                  label: Text(uiGallery, style: const TextStyle(fontSize: 18)),
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
// SEITE 1.5: KAMERA MIT NATIVEM IOS ZOOM & LINSENWECHSEL
// ==========================================
class CustomCameraScreen extends StatefulWidget {
  final String defaultAddress;
  const CustomCameraScreen({super.key, required this.defaultAddress});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isTakingPicture = false;

  int _wideIndex = -1;
  int _ultraWideIndex = -1;
  int _teleIndex = -1;
  int _currentCameraIndex = 0;

  final List<double> _availableZoomLevels = [
    0.5, 0.6, 0.7, 0.8, 0.9, 
    1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 
    2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 
    3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0
  ];
  
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  
  double _currentDisplayZoom = 1.0;
  double _baseZoomLevel = 1.0;
  int _selectedZoomIndex = 5; 

  late FixedExtentScrollController _zoomScrollController;
  Timer? _lensSwitchTimer;

  @override
  void initState() {
    super.initState();
    _zoomScrollController = FixedExtentScrollController(initialItem: _selectedZoomIndex);

    List<int> backCams = [];
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.back) {
        backCams.add(i);
        String name = cameras[i].name.toLowerCase();
        
        if (name.contains('ultra') || name.contains('0.5') || name.contains('0,5')) {
          _ultraWideIndex = i;
        } else if (name.contains('tele')) {
          _teleIndex = i;
        } else if (_wideIndex == -1) {
          _wideIndex = i;
        }
      }
    }

    if (_ultraWideIndex == -1 && backCams.length > 1) {
      if (backCams.length == 3) {
        _teleIndex = backCams[1];
        _ultraWideIndex = backCams[2];
      } else if (backCams.length == 2) {
        _ultraWideIndex = backCams[1];
      }
    }

    if (_wideIndex == -1) {
      _wideIndex = backCams.isNotEmpty ? backCams[0] : 0;
    }

    _currentCameraIndex = _wideIndex;
    _initCamera(_currentCameraIndex, 1.0);
  }

  Future<void> _initCamera(int cameraIndex, double displayZoom) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      _minAvailableZoom = await _controller!.getMinZoomLevel();
      
      _currentCameraIndex = cameraIndex;
      _applyZoom(displayZoom);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Kamera konnte nicht geladen werden: $e");
    }
  }

  void _applyZoom(double displayZoom) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    double internalZoom = displayZoom;
    if (_currentCameraIndex == _ultraWideIndex) {
      internalZoom = displayZoom * 2.0; 
    } else if (_currentCameraIndex == _wideIndex) {
      internalZoom = displayZoom;
    } else if (_currentCameraIndex == _teleIndex) {
      internalZoom = displayZoom / 3.0; 
    }

    internalZoom = internalZoom.clamp(_minAvailableZoom, _maxAvailableZoom);
    try {
      _controller!.setZoomLevel(internalZoom);
    } catch (e) {
      debugPrint("Zoom blockiert: $e");
    }
  }

  void _onWheelChanged(int index) {
    setState(() {
      _selectedZoomIndex = index;
      _currentDisplayZoom = _availableZoomLevels[index];
    });

    _applyZoom(_currentDisplayZoom);

    _lensSwitchTimer?.cancel();
    _lensSwitchTimer = Timer(const Duration(milliseconds: 250), () {
      _evaluateLensSwitch(_currentDisplayZoom);
    });
  }

  void _evaluateLensSwitch(double displayZoom) {
    int targetLens = _currentCameraIndex;

    if (displayZoom < 1.0 && _ultraWideIndex != -1) {
      targetLens = _ultraWideIndex;
    } else if (displayZoom >= 3.0 && _teleIndex != -1) {
      targetLens = _teleIndex;
    } else if (displayZoom >= 1.0 && displayZoom < 3.0 && _wideIndex != -1) {
      targetLens = _wideIndex;
    }

    if (targetLens != _currentCameraIndex) {
      _initCamera(targetLens, displayZoom);
    }
  }

  void _jumpToZoom(double targetZoom) {
    int idx = _availableZoomLevels.indexOf(targetZoom);
    if (idx == -1) return;

    setState(() {
      _selectedZoomIndex = idx;
      _currentDisplayZoom = targetZoom;
    });
    _zoomScrollController.jumpToItem(idx);
    _evaluateLensSwitch(targetZoom);
  }

  Future<void> _takePictureAndGo() async {
    if (_isTakingPicture || _controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() {
        _isTakingPicture = true;
      });
      
      final image = await _controller!.takePicture();
      
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

  Widget _buildQuickJumpButton(double zoomValue, String label) {
    bool isActive = _currentDisplayZoom == zoomValue;
    return GestureDetector(
      onTap: () => _jumpToZoom(zoomValue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.yellow : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lensSwitchTimer?.cancel();
    _zoomScrollController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: (_controller != null && _controller!.value.isInitialized)
                  ? GestureDetector(
                      onScaleStart: (details) {
                        _baseZoomLevel = _currentDisplayZoom;
                      },
                      onScaleUpdate: (details) async {
                        double zoom = _baseZoomLevel * details.scale;
                        zoom = zoom.clamp(0.5, 15.0);
                        
                        int closestIndex = 0;
                        double minDiff = double.infinity;
                        for(int i = 0; i < _availableZoomLevels.length; i++) {
                          double diff = (zoom - _availableZoomLevels[i]).abs();
                          if(diff < minDiff) {
                            minDiff = diff;
                            closestIndex = i;
                          }
                        }
                        
                        if (_selectedZoomIndex != closestIndex) {
                          _zoomScrollController.jumpToItem(closestIndex);
                          _onWheelChanged(closestIndex);
                        }
                      },
                      child: CameraPreview(_controller!),
                    )
                  : const SizedBox.shrink(),
            ),

            Positioned(
              bottom: 120, 
              left: 0,
              right: 0,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.4, 0.6, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: SizedBox(
                  height: 70, 
                  child: RotatedBox(
                    quarterTurns: -1, 
                    child: ListWheelScrollView.useDelegate(
                      controller: _zoomScrollController,
                      itemExtent: 22, 
                      physics: const FixedExtentScrollPhysics(), 
                      perspective: 0.001, 
                      diameterRatio: 3.0, 
                      onSelectedItemChanged: _onWheelChanged,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _availableZoomLevels.length,
                        builder: (context, index) {
                          double zoomValue = _availableZoomLevels[index];
                          bool isSelected = index == _selectedZoomIndex;
                          bool isMainLabel = zoomValue % 1 == 0 || zoomValue == 0.5;

                          Widget content;
                          if (isMainLabel) {
                            content = Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  child: OverflowBox(
                                    maxWidth: 120, 
                                    maxHeight: 50,
                                    alignment: Alignment.center,
                                    child: Text(
                                      zoomValue.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','),
                                      style: TextStyle(
                                        color: isSelected ? Colors.yellow : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSelected ? 15 : 13,
                                      ),
                                      maxLines: 1,
                                      softWrap: false, 
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 1.5,
                                  height: 18,
                                  color: isSelected ? Colors.yellow : Colors.white,
                                ),
                              ],
                            );
                          } else {
                            content = Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24), 
                                Container(
                                  width: 1.0,
                                  height: 10,
                                  color: Colors.white54,
                                ),
                              ],
                            );
                          }

                          return RotatedBox(
                            quarterTurns: 1, 
                            child: Container(
                              alignment: Alignment.center,
                              child: content,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 200, 
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_ultraWideIndex != -1) _buildQuickJumpButton(0.5, "0,5"),
                  _buildQuickJumpButton(1.0, "1"),
                  _buildQuickJumpButton(2.0, "2"),
                  if (_teleIndex != -1) _buildQuickJumpButton(3.0, "3"),
                ],
              ),
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

  late Map<String, String> _toolOptionsMap;

  Offset? _lengthStart, _lengthEnd;
  Offset? _widthStart, _widthEnd;
  Offset? _depthStart, _depthEnd;
  
  Offset? _notePos1;
  Offset? _notePos2;
  Offset? _notePos3;
  Offset? _addressPos;

  @override
  void initState() {
    super.initState();
    _toolOptionsMap = {};
    toolTerms.forEach((key, term) {
      _toolOptionsMap[term.display] = key;
    });
  }

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
            SnackBar(
              content: Text(uiSavedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
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
      backgroundColor: Colors.black, 
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text('$uiMode ${toolTerms[_activeToolKey]?.display ?? _activeToolKey}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        foregroundColor: Colors.white, 
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            onPressed: _openDataInputScreen,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: _isSaving ? null : () => _saveToGallery(context),
              child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(uiSaveToPhotos, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Screenshot(
              controller: _screenshotController,
              child: FutureBuilder<Size>(
                future: _getImageSize(widget.currentImage),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                                lengthStart: _lengthStart, lengthEnd: _lengthEnd, lengthLabel: "${toolTerms['Länge']!.outputLang}: $_lengthText",
                                widthStart: _widthStart, widthEnd: _widthEnd, widthLabel: "${toolTerms['Breite']!.outputLang}: $_widthText",
                                depthStart: _depthStart, depthEnd: _depthEnd, depthLabel: "${toolTerms['Tiefe']!.outputLang}: $_depthText",
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

          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 12, 
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                  color: Colors.white.withOpacity(0.75), 
                  child: Row(
                    children: [
                      Text(uiMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isDense: true, 
                            value: _getCurrentToolDisplayValue(),
                            isExpanded: true,
                            itemHeight: null, 
                            dropdownColor: Colors.white,
                            selectedItemBuilder: (BuildContext context) {
                              return _toolOptionsMap.keys.map<Widget>((String displayLabel) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    displayLabel,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items: _toolOptionsMap.keys.map((String displayLabel) {
                              return DropdownMenuItem<String>(
                                value: displayLabel,
                                child: Text(displayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              );
                            }).toList(),
                            onChanged: (String? selectedDisplayLabel) {
                              if (selectedDisplayLabel != null) {
                                setState(() {
                                  _activeToolKey = _toolOptionsMap[selectedDisplayLabel]!;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _openDataInputScreen,
                        icon: const Icon(Icons.list_alt, size: 16),
                        label: Text(uiData, style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ],
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

  late Map<String, String> _versorgerOptionsMap;
  late Map<String, String> _materialOptionsMap;
  late Map<String, String> _taetigkeitOptionsMap;

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

    _versorgerOptionsMap = { for (var t in versorgerTerms) t.dropdownLabel : t.sourceLang };
    _materialOptionsMap = { for (var t in materialTerms) t.dropdownLabel : t.sourceLang };
    _taetigkeitOptionsMap = { for (var t in taetigkeitTerms) t.dropdownLabel : t.sourceLang };
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

  // ==========================================
  // HIER ARBEITET DAS MEGA-OFFLINE-WÖRTERBUCH
  // ==========================================
  String _translateLive(String input) {
    if (input.trim().isEmpty) return '';
    String result = input;
    
    // Sortiere nach Länge, damit lange Wörter zuerst ersetzt werden
    List<Term> sortedTerms = List.from(allDictionaryTerms);
    sortedTerms.sort((a, b) => b.ru.length.compareTo(a.ru.length));

    for (var term in sortedTerms) {
      // Sucht flexibel (egal ob Groß- или Kleinschreibung) und ersetzt es durch Deutsch
      result = result.replaceAll(RegExp(term.ru, caseSensitive: false), term.de);
      result = result.replaceAll(RegExp(term.uk, caseSensitive: false), term.de);
    }
    return result;
  }

  void _saveAndReturn() {
    Navigator.pop(context, {
      'length': _lengthController.text,
      'width': _widthController.text,
      'depth': _depthController.text,
      // HIER GEHT JETZT NUR DAS ÜBERSETZTE DEUTSCHE WORT AUF DAS FOTO
      'note1': _translateLive(_noteController1.text),
      'note2': _translateLive(_noteController2.text),
      'note3': _translateLive(_noteController3.text),
      'address': _addressController.text,
    });
  }

  void _appendToNote(String? selectedDisplayLabel, TextEditingController controller, Map<String, String> mapToUse) {
    if (selectedDisplayLabel != null) {
      final targetValue = mapToUse[selectedDisplayLabel]!;
      setState(() {
        if (controller.text.isEmpty) {
          controller.text = targetValue;
        } else {
          controller.text = "${controller.text} - $targetValue";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: Text(uiInputTitle, style: const TextStyle(fontSize: 16)), 
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 26),
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
              decoration: InputDecoration(
                labelText: toolTerms['Länge']!.display,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _widthController,
              decoration: InputDecoration(
                labelText: toolTerms['Breite']!.display,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _depthController,
              decoration: InputDecoration(
                labelText: toolTerms['Tiefe']!.display,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            const Divider(height: 32, thickness: 2),

            // =========================
            // BLOCK 1 (Versorger)
            // =========================
            TextField(
              controller: _noteController1,
              onChanged: (val) {
                // UI aktualisieren, damit die Live-Übersetzung angezeigt wird
                setState(() {}); 
              },
              decoration: InputDecoration(
                labelText: uiNote1,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () {
                    _noteController1.clear();
                    setState(() {});
                  },
                ),
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            // LIVE-ÜBERSETZUNG IN GRÜN DIREKT DARUNTER
            if (_noteController1.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                child: Text(
                  "🇩🇪 ${_translateLive(_noteController1.text)}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: InputDecoration(
                labelText: uiSelect1,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: 80.0,
                  hint: Text(uiHint1, style: const TextStyle(fontSize: 14)), 
                  items: [
                    DropdownMenuItem<String>(
                      value: 'BACK',
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(backTerm.display, style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ..._versorgerOptionsMap.keys.map((String displayLabel) {
                      return DropdownMenuItem<String>(
                        value: displayLabel,
                        child: Text(
                          displayLabel, 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
                          softWrap: true,
                          maxLines: 3,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val == 'BACK' || val == null) return;
                    _appendToNote(val, _noteController1, _versorgerOptionsMap);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =========================
            // BLOCK 2 (Material)
            // =========================
            TextField(
              controller: _noteController2,
              onChanged: (val) {
                setState(() {}); 
              },
              decoration: InputDecoration(
                labelText: uiNote2,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () {
                    _noteController2.clear();
                    setState(() {});
                  },
                ),
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            if (_noteController2.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                child: Text(
                  "🇩🇪 ${_translateLive(_noteController2.text)}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: InputDecoration(
                labelText: uiSelect2,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: 80.0,
                  hint: Text(uiHint2, style: const TextStyle(fontSize: 14)), 
                  items: [
                    DropdownMenuItem<String>(
                      value: 'BACK',
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(backTerm.display, style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ..._materialOptionsMap.keys.map((String displayLabel) {
                      return DropdownMenuItem<String>(
                        value: displayLabel,
                        child: Text(
                          displayLabel, 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
                          softWrap: true,
                          maxLines: 3,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val == 'BACK' || val == null) return;
                    _appendToNote(val, _noteController2, _materialOptionsMap);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =========================
            // BLOCK 3 (Tätigkeit)
            // =========================
            TextField(
              controller: _noteController3,
              onChanged: (val) {
                setState(() {}); 
              },
              decoration: InputDecoration(
                labelText: uiNote3,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  onPressed: () {
                    _noteController3.clear();
                    setState(() {});
                  },
                ),
              ),
              style: const TextStyle(fontSize: 14), 
            ),
            if (_noteController3.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                child: Text(
                  "🇩🇪 ${_translateLive(_noteController3.text)}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: InputDecoration(
                labelText: uiSelect3,
                labelStyle: const TextStyle(fontSize: 13), 
                isDense: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: 80.0,
                  hint: Text(uiHint3, style: const TextStyle(fontSize: 14)), 
                  items: [
                    DropdownMenuItem<String>(
                      value: 'BACK',
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(backTerm.display, style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ..._taetigkeitOptionsMap.keys.map((String displayLabel) {
                      return DropdownMenuItem<String>(
                        value: displayLabel,
                        child: Text(
                          displayLabel, 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), 
                          softWrap: true,
                          maxLines: 3,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val == 'BACK' || val == null) return;
                    _appendToNote(val, _noteController3, _taetigkeitOptionsMap);
                  },
                ),
              ),
            ),
            const Divider(height: 32, thickness: 2),

            TextField(
              controller: _addressController,
              maxLines: null, 
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: uiAddress,
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
                label: Text(uiAcceptReturn, style: const TextStyle(fontSize: 15)), 
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
      _drawTextBadge(canvas, addressPos!, addressLabel, Colors.black87, scale: scale, sizeMultiplier: 0.5);
    }
  }

  void _drawArrowLineWithParallelLabel(Canvas canvas, Offset start, Offset end, String label, {required bool twoArrows, required double scale}) {
    bool isEmptyLabel = label.endsWith(": ");
    
    if ((end - start).distance < 5 || label.isEmpty || isEmptyLabel) {
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

    final paddingH = 8.0 * scale; 
    final paddingV = 4.0 * scale; 

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

  void _drawTextBadge(Canvas canvas, Offset pos, String text, Color bgColor, {required double scale, double sizeMultiplier = 1.0}) {
    final double currentFontSize = math.max(18.0, 26.0 * scale) * sizeMultiplier;
    
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: currentFontSize,
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

    final paddingH = 20.0 * scale * sizeMultiplier; 
    final paddingV = 12.0 * scale * sizeMultiplier; 

    final rect = Rect.fromCenter(
      center: pos,
      width: textPainter.width + (paddingH * 2),
      height: textPainter.height + (paddingV * 2),
    );
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(8.0 * scale * sizeMultiplier)); 

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