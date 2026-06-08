import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show(BuildContext context, {required String message, required Color color, IconData? icon}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // إخفاء أي رسالة سابقة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
              )
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // هنا السر لجعله عائماً
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}