import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'registration_screen.dart';
import '../providers/navigation_provider.dart';
import '../l10n/app_localizations.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const RegistrationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => ref.read(navigationProvider.notifier).state = index,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF87A96B),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded, size: 28),
              label: 'Pesquisar',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              activeIcon: const Icon(Icons.history_rounded, size: 28),
              label: AppLocalizations.of(context).translate('history_title'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_a_photo_rounded),
              activeIcon: const Icon(Icons.add_a_photo_rounded, size: 28),
              label: AppLocalizations.of(context).translate('my_records'),
            ),
          ],
        ),
      ),
    );
  }
}
