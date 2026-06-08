import 'package:flutter/material.dart';
import 'package:myhalaqat/features/dashboard/screens/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/features/auth/screens/login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    
    if (mounted) {
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAuthenticated) {
      return const MainScreen(); 
    } else {
      return const LoginScreen(); 
    }
  }
}