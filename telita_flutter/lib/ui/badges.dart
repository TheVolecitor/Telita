import 'package:flutter/material.dart';

class Badge4K extends StatelessWidget {
  const Badge4K({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        '4K',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class BadgeDV extends StatelessWidget {
  const BadgeDV({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '◗◖',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 14,
              letterSpacing: -1,
            ),
          ),
          SizedBox(width: 3),
          Text(
            'VISION',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeHDR10 extends StatelessWidget {
  const BadgeHDR10({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'HDR10+',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class BadgeHDR extends StatelessWidget {
  const BadgeHDR({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'HDR',
        style: TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class Badge51 extends StatelessWidget {
  const Badge51({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF475569)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        '5.1',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class BadgeAtmos extends StatelessWidget {
  const BadgeAtmos({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '◗◖',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 16,
              letterSpacing: -1,
            ),
          ),
          SizedBox(width: 3),
          Text(
            'ATMOS',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeDDP extends StatelessWidget {
  const BadgeDDP({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '◗◖',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 16,
              letterSpacing: -1,
            ),
          ),
          SizedBox(width: 3),
          Text(
            'DDP 5.1',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeDTS extends StatelessWidget {
  const BadgeDTS({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'DTS',
        style: TextStyle(
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}
