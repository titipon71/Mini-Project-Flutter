import 'package:flutter/material.dart';
import 'package:my_app/screens/sign_in_screen.dart';
import 'package:my_app/screens/sign_up_screen.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:my_app/screens/navbar2_screen.dart';
import 'package:my_app/assets/widgets/example_sidebarx.dart';
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: Navbar2(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: ExampleSidebarX(controller: _controller), // ✅ ใช้ได้แล้ว
      body: Row(
        children: [
          if (isWide) ExampleSidebarX(controller: _controller),
          Expanded(
            child: IndexedStack(
              index: _controller.selectedIndex,
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
