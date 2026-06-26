import 'package:Twebtoon/assets/widgets/app_sidebar.dart';
import 'package:Twebtoon/screens/navbar2_screen.dart';
import 'package:flutter/material.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: Navbar2(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const Drawer(child: AppSidebar()),
      body: Row(
        children: [
          if (isWide) const AppSidebar(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                // TODO: ใส่หน้าตามเมนูของคุณ
                Placeholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
