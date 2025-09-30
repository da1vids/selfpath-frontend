import 'package:flutter/material.dart';

class AppTheme {
  static const Color accentColor = Color(0xFF9061FF);
  static const Color darkBg = Color(0xFF000000);
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color fieldFillDark = Color(0xFF1D1D1D);
  static const Color fieldFillLight = Color(0xFFF2F2F2);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: accentColor,
      fontFamily: 'Roboto',
      canvasColor: darkBg,
      dialogBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(backgroundColor: darkBg),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillDark,
        labelStyle: TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 50),
          shape: StadiumBorder(),
        ),
      ),

      textTheme: TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        bodyLarge: TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: accentColor,
      fontFamily: 'Roboto',

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillLight,
        labelStyle: TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 50),
          shape: StadiumBorder(),
        ),
      ),

      textTheme: TextTheme(
        bodyMedium: TextStyle(color: Colors.black87),
        bodyLarge: TextStyle(color: Colors.black),
      ),
    );
  }
}
