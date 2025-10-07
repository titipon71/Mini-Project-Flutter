import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_app/assets/widgets/vip_status_widget.dart';
import 'package:my_app/screens/admin_dashboard_screen.dart';
import 'package:my_app/screens/home2_screen.dart';
import 'package:my_app/screens/sign_in_screen.dart';
import 'package:my_app/screens/sign_up_screen.dart';
import 'package:my_app/screens/topup_screen.dart';
import 'package:my_app/services/vip_service.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/helpers/user_role_extension.dart'; // .isAdmin(), .isVIP()
import 'package:cloud_firestore/cloud_firestore.dart';


class ExampleSidebarX extends StatefulWidget {
  const ExampleSidebarX({super.key, required this.controller});
  final SidebarXController controller;

  @override
  State<ExampleSidebarX> createState() => _ExampleSidebarXState();
}

class _ExampleSidebarXState extends State<ExampleSidebarX> {
  final Stream<User?> _auth$ = FirebaseAuth.instance.authStateChanges();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vipSub;

  bool _isVIP = false;
  bool _vip = false;
  bool _isAdmin = false;
  bool _loadingRole = true;
  String? _lastUid; // ใช้ตรวจว่า user เปลี่ยนหรือยัง
 Future<void> checkVip() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final vip = await isVip(uid);
  print('VIP status: $vip');
  setState(() {
    _vip = vip;
  });
}
void _listenVip(String uid) {
  _vipSub?.cancel();
  _vipSub = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .listen((snap) {
    final v = (snap.data()?['roles']?['vip'] ?? false) as bool;
    if (mounted) setState(() => _vip = v);
  }, onError: (_) {
    if (mounted) setState(() => _vip = false);
  });
}

  @override
  void initState() {
    super.initState();
    _loadUserRole(); // เผื่อกรณีมี user อยู่แล้ว
  }

  @override
void dispose() {
  _vipSub?.cancel();
  super.dispose();
}

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _isVIP = false;
        _loadingRole = false;
        _lastUid = null;
      });
      return;
    }

    final isAdmin = await user.isAdmin(refresh: true); // (รีเฟรช token ภายใน)
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _loadingRole = false;
      _lastUid = user.uid;
    });
  }

  Future<void> signOutFromAllProviders() async {
    await FirebaseAuth.instance.signOut();
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth$,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSignedIn = user != null;

        
        // ถ้า user เปลี่ยน (login/logout/switch) ให้โหลด role ใหม่ 1 ครั้ง
        if (user?.uid != _lastUid) {
  _loadingRole = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _vipSub?.cancel();                           // ปลดของเก่า
    if (user != null) _listenVip(user.uid);      // 👈 ผูกตัวใหม่
    _loadUserRole();                              // โหลดสถานะแอดมินเหมือนเดิม
  });
}

        // ชื่อที่จะแสดง
        final String displayName = () {
          final direct = user?.displayName?.trim();
          if (direct != null && direct.isNotEmpty) return direct;
          final fromProvider = user?.providerData
              .map((p) => p.displayName)
              .firstWhere(
                (n) => n != null && n.trim().isNotEmpty,
                orElse: () => null,
              );
          if (fromProvider != null) return fromProvider;
          return user?.email ?? 'User';
          
        }();

        // สร้างรายการเมนูตามสถานะ
        final List<SidebarXItem> items = [
          

          if (isSignedIn)
            
            SidebarXItem(
              
              icon: Icons.account_circle,
              label: displayName,
              onTap: () {},
            ),
          if (isSignedIn && _vip)
            SidebarXItem(
              icon: Icons.workspace_premium,
              label: '🌟 VIP User',
              onTap: () {},
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
          if (!isSignedIn)
            SidebarXItem(
              icon: Icons.login,
              label: 'Sign In',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignInScreen()),
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
                  MaterialPageRoute(builder: (_) => SignUpScreen()),
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
                  MaterialPageRoute(builder: (_) => TopupScreen()),
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
                if (!mounted) return;
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TopupScreen()),
                );
              } else {
                _showNeedSignInDialog(context, 'Settings');
              }
            },
          ),
          if (isSignedIn)
            SidebarXItem(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: () async {
                await signOutFromAllProviders();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
              },
            ),
          // ✅ โชว์เฉพาะแอดมิน — ใช้ค่า `_isAdmin` ที่ cache แล้ว
          if (_isAdmin && !_loadingRole)
            SidebarXItem(
              icon: Icons.engineering,
              label: 'Developer',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
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
            itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            selectedItemPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemTextPadding: const EdgeInsets.only(left: 16),
            selectedItemTextPadding: const EdgeInsets.only(left: 16),
            iconTheme: const IconThemeData(color: Colors.white),
            textStyle: const TextStyle(color: Colors.white),
            hoverColor: Colors.grey[900],
            hoverIconTheme: const IconThemeData(color: Colors.white),
            hoverTextStyle: const TextStyle(color: Colors.white),
            selectedItemDecoration: const BoxDecoration(color: Colors.transparent),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedTextStyle: const TextStyle(color: Colors.white),
            itemDecoration: const BoxDecoration(color: Colors.transparent),
          ),
          extendedTheme: const SidebarXTheme(
            width: 250,
            decoration: BoxDecoration(color: Colors.black),
            selectedItemPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemTextPadding: EdgeInsets.only(left: 16),
            selectedItemTextPadding: EdgeInsets.only(left: 16),
          ),
          headerBuilder: (context, extended) {
            return const SizedBox(
              height: 100,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Icon(Icons.menu, color: Colors.white, size: 24)),
              ),
            );
          },
          items: items,
        );
      },
    );
  }

  void _showNeedSignInDialog(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Not Signed In', style: TextStyle(color: Colors.white)),
        content: Text(
          'Please sign in to access "$actionName".',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}