import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../booking/screens/host_dashboard_screen.dart';
import '../../charger/screens/my_chargers_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HostMainScreen extends ConsumerStatefulWidget {
  const HostMainScreen({super.key});

  @override
  ConsumerState<HostMainScreen> createState() => _HostMainScreenState();
}

class _HostMainScreenState extends ConsumerState<HostMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HostDashboardScreen(),
    const MyChargersScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF22C55E),
          unselectedItemColor: const Color(0xFF9CA3AF),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.ev_station_outlined),
              activeIcon: Icon(Icons.ev_station),
              label: 'Chargers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
