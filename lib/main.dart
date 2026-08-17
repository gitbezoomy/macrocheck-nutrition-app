import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_screen.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt', null);
  await initializeDateFormatting('en', null);

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'NutriSearch',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [
        Locale('pt'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF87A96B), // Sage Green
          primary: const Color(0xFF87A96B),
          secondary: const Color(0xFF9EAFC1), // Silver Sage
          tertiary: const Color(0xFF2D3142), // Charcoal
          surface: const Color(0xFFFBFBF9), // Cream Off-white
        ),
        scaffoldBackgroundColor: const Color(0xFFFBFBF9),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          shadowColor: Colors.black.withValues(alpha: 0.05),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
