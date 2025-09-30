import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_app/screens/admin_dashboard_screen.dart';
import 'package:my_app/screens/home2_screen.dart';
import 'package:my_app/screens/sign_in_screen.dart';
import 'package:my_app/screens/sign_up_screen.dart';
import 'package:my_app/screens/topup_screen.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ถ้าใช้งานจริง ให้เปิดคอมเมนต์และเพิ่มใน pubspec.yaml ด้วย
// google_sign_in: ^6.2.1
// flutter_facebook_auth: ^6.0.4
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class ExampleSidebarX extends StatefulWidget {
  const ExampleSidebarX({super.key, required this.controller});
  final SidebarXController controller;

  @override
  State<ExampleSidebarX> createState() => _ExampleSidebarXState();
}

class _ExampleSidebarXState extends State<ExampleSidebarX> {
  // ฟังการเปลี่ยนแปลงสถานะล็อกอินแบบ real-time
  final Stream<User?> _auth$ = FirebaseAuth.instance.authStateChanges();

  Future<void> signOutFromAllProviders() async {
    // ออกจาก Firebase (ครอบคลุม GitHub/OAuth ส่วนใหญ่)
    await FirebaseAuth.instance.signOut();

    // ถ้าแอปคุณมีลง Google/Facebook ไว้ ให้เอาคอมเมนต์ออก:
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }
    } catch (_) {}

    //   try {
    //     await FacebookAuth.instance.logOut();
    //   } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth$,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final bool isSignedIn = user != null;

        final String displayName = () {
          final direct = user?.displayName?.trim();
          if (direct != null && direct.isNotEmpty) return direct;
          // บาง provider (เช่น GitHub) อาจเก็บชื่อไว้ใน providerData
          final fromProvider = user?.providerData
              .map((p) => p.displayName)
              .firstWhere(
                (n) => n != null && n.trim().isNotEmpty,
                orElse: () => null,
              );
          if (fromProvider != null) return fromProvider;
          return user?.email ?? 'User';
        }();

        // สร้างรายการเมนูแบบไดนามิก
        final List<SidebarXItem> items = [
          // ✅ แสดงชื่อผู้ใช้เป็นรายการแรก เมื่อ "ล็อกอินแล้ว"
          if (isSignedIn)
            SidebarXItem(
              icon: Icons.account_circle,
              label: displayName,
              onTap: () {
                // TODO: ไปหน้าโปรไฟล์ถ้ามี
                // Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
          if (isSignedIn)
             SidebarXItem(
              icon: Icons.home,
              label: 'Home',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Home2Screen()),
                );
              },
            ),
          // ✅ ซ่อน Sign In/Sign Up เมื่อ "ล็อกอินแล้ว"
          if (!isSignedIn)
            SidebarXItem(
              icon: Icons.login,
              label: 'Sign In',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignInScreen()),
                );
              },
            ),
          if (!isSignedIn)
            SidebarXItem(
              icon: Icons.app_registration,
              label: 'Sign Up',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
            ),

          SidebarXItem(
            icon: Icons.workspace_premium,
            label: 'Top up VIP',
            onTap: () {
              if (isSignedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TopupScreen()),
                );
              } else {
                _showNeedSignInDialog(context, 'Top up VIP');
              }
            },
          ),
          SidebarXItem(
            icon: Icons.contact_support,
            label: 'Contact Us',
            onTap: () async {
              final Uri url = Uri.parse("https://line.me/R/ti/p/@362odwuo");
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $url')),
                );
              }
            },
          ),
          SidebarXItem(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {
              if (isSignedIn) {
                // TODO: เปลี่ยนไปหน้า Settings จริงของคุณ
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TopupScreen()),
                );
              } else {
                _showNeedSignInDialog(context, 'Settings');
              }
            },
          ),

          // ✅ โชว์ปุ่ม Sign Out เฉพาะตอน "ล็อกอินแล้ว"
          if (isSignedIn)
            SidebarXItem(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: () async {
                await signOutFromAllProviders();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                }
              },
            ),

          SidebarXItem(
            icon: Icons.engineering,
            label: 'Developer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            },
          ),
        ];

        return SidebarX(
          controller: widget.controller,
          showToggleButton: false,
          animationDuration: Duration.zero,
          theme: SidebarXTheme(
            decoration: const BoxDecoration(color: Colors.black),
            width: 250,
            itemPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            selectedItemPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            itemTextPadding: const EdgeInsets.only(left: 16),
            selectedItemTextPadding: const EdgeInsets.only(left: 16),
            iconTheme: const IconThemeData(color: Colors.white),
            textStyle: const TextStyle(color: Colors.white),
            hoverColor: Colors.grey[900],
            hoverIconTheme: const IconThemeData(color: Colors.white),
            hoverTextStyle: const TextStyle(color: Colors.white),
            selectedItemDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedTextStyle: const TextStyle(color: Colors.white),
            itemDecoration: const BoxDecoration(color: Colors.transparent),
          ),
          extendedTheme: const SidebarXTheme(
            width: 250,
            decoration: BoxDecoration(color: Colors.black),
            selectedItemPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            itemTextPadding: EdgeInsets.only(left: 16),
            selectedItemTextPadding: EdgeInsets.only(left: 16),
          ),
          headerBuilder: (context, extended) {
            return const SizedBox(
              height: 100,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Icon(Icons.menu, color: Colors.white, size: 24),
                ),
              ),
            );
          },
          items: items,
        );
      },
    );
  }

  void _showNeedSignInDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Not Signed In',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Please sign in to access the $featureName feature.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
