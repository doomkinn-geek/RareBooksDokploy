import 'package:flutter/material.dart';

/// Показывает SnackBar вверху экрана, чтобы не мешать вводу сообщений
void showTopSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).size.height - 100,
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Показывает SnackBar внизу экрана (стандартное поведение)
void showBottomSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
      duration: const Duration(seconds: 3),
    ),
  );
}

