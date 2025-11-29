import 'package:flutter/material.dart';
import 'conversations_home_page.dart';
import 'redactor_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [ConversationsHomePage(), RedactorPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF16213E),
        indicatorColor: const Color(0xFF00D9FF).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.mic, color: Color(0xFF00D9FF)),
            label: 'Recorder',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.security, color: Color(0xFF00D9FF)),
            label: 'Redactor',
          ),
        ],
      ),
    );
  }
}
