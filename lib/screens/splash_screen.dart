import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon bars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(20),
                  const SizedBox(width: 6),
                  _bar(35),
                  const SizedBox(width: 6),
                  _bar(50),
                  const SizedBox(width: 6),
                  _bar(35),
                  const SizedBox(width: 6),
                  _bar(20),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'SAGA TUNES',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE8C547),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Free Audio. Always Free.',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: const Color(0xFF7A7890),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8C547),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                  child: const Text('Get Started', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A0A0F))),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text(
                  'BROWSE WITHOUT ACCOUNT',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF7A7890), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 8, height: height,
      decoration: BoxDecoration(color: const Color(0xFFE8C547), borderRadius: BorderRadius.circular(4)),
    );
  }
}
