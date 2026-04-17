import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1DB954),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station),
            label: 'My Chargers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
