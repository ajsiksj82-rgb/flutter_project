// ============================================================
// نظام إدارة معهد سمارت سكلز — الإصدار 3.0
// تطوير: أحمد الشريف
//
// الإضافات في هذا الإصدار:
//  • طباعة/مشاركة PDF: سند القبض، سند الصرف، كشف حساب المتدرب،
//    قوائم المتدربين والدورات، كشوف التحصيل والمصروفات، الملخص المالي،
//    المديونيات، كشف الحضور، كشوف الدرجات وشهادة درجات المتدرب.
//  • الدرجات: إدخال يدوي + استيراد من Excel + قالب Excel + تصدير.
//  • استيراد المتدربين من Excel وتصدير المتدربين والسندات.
//  • نسخ احتياطي واستعادة قاعدة البيانات.
//  • بيانات المطور في الإعدادات.
// ============================================================
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

// ---------- أجزاء الملف ----------
part 'db_part.dart';
part 'shell_part.dart';
part 'shared_part.dart';
part 'dashboard_students_part.dart';
part 'courses_finance_part.dart';
part 'instructors_part.dart';
part 'security_part.dart';
part 'attendance_part.dart';
part 'reports_grades_part.dart';
part 'backup_settings_part.dart';
part 'xlsx_tools_part.dart';
part 'print_service_part.dart';

// ---------- بيانات المطور (تظهر في الإعدادات) ----------
const String kDevName = 'أحمد الشريف';
const String kDevPhone = '+967 771 274 274';
const String kDevEmail = 'ahmadalshareef102@gmail.com';
const String kAppVersion = 'Smart Skills Management 3.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDB.instance.init();
  runApp(const SmartSkillsApp());
}