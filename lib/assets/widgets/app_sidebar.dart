import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Twebtoon/screens/admin_dashboard_screen.dart';
import 'package:Twebtoon/screens/home2_screen.dart';
import 'package:Twebtoon/screens/sign_in_screen.dart';
import 'package:Twebtoon/screens/sign_up_screen.dart';
import 'package:Twebtoon/screens/topup_history_screen.dart';
import 'package:Twebtoon/screens/topup_screen.dart';
import 'package:Twebtoon/screens/user_settings_screen.dart';
import 'package:Twebtoon/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Twebtoon/services/api_service.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final Stream<User?> _auth$ = FirebaseAuth.instance.authStateChanges();

  bool _vip = false;
  bool _isAdmin = false;
  bool _loadingRole = true;
  String? _lastUid;
  DateTime? _vipUntil;

  static const _itemPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 4);
  static const _textStyle = TextStyle(color: Colors.white);
  static const _iconTheme = IconThemeData(color: Colors.white);

  String _formatDate(DateTime dt) {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _vip = false;
          _vipUntil = null;
          _loadingRole = false;
          _lastUid = null;
        });
      }
      return;
    }

    try {
      final response = await ApiService.get('/api/v1/me/roles');
      if (response.statusCode == 200 && mounted) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final vipUntilStr = json['vipUntil'] as String?;
        final DateTime? vipUntil =
            vipUntilStr != null ? DateTime.tryParse(vipUntilStr)?.toLocal() : null;
        final bool vipActive =
            json['vip'] == true && vipUntil != null && vipUntil.isAfter(DateTime.now());
        setState(() {
          _isAdmin = json['admin'] == true;
          _vip = vipActive;
          _vipUntil = vipUntil;
          _loadingRole = false;
          _lastUid = user.uid;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _vip = false;
          _vipUntil = null;
          _loadingRole = false;
          _lastUid = user.uid;
        });
      }
    }
  }

  Future<void> signOutFromAllProviders() async {
    await AuthService.signOut();
  }

  void _closeDrawerIfOpen(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    _closeDrawerIfOpen(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: _itemPadding,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconTheme(data: _iconTheme, child: Icon(icon)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: _textStyle, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth$,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSignedIn = user != null;

        if (user?.uid != _lastUid) {
          _loadingRole = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadUserRole();
          });
        }

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

        return Container(
          width: MediaQuery.of(context).size.width.clamp(250.0, 350.0),
          color: Colors.black,
          child: Column(
            children: [
              const SizedBox(
                height: 100,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Icon(Icons.menu, color: Colors.white, size: 24),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (isSignedIn)
                      _menuTile(icon: Icons.account_circle, label: displayName),
                    if (isSignedIn && _isAdmin)
                      _menuTile(icon: Icons.workspace_premium, label: 'Admin'),
                    if (isSignedIn && _vip && !_isAdmin)
                      _menuTile(
                        icon: Icons.workspace_premium,
                        label: '🌟 VIP (${_formatDate(_vipUntil!)})',
                      ),
                    if (isSignedIn)
                      _menuTile(
                        icon: Icons.home,
                        label: 'Home',
                        onTap: () => _navigateTo(context, const Home2Screen()),
                      ),
                    if (!isSignedIn)
                      _menuTile(
                        icon: Icons.login,
                        label: 'Sign In',
                        onTap: () => _navigateTo(context, SignInScreen()),
                      ),
                    if (!isSignedIn)
                      _menuTile(
                        icon: Icons.app_registration,
                        label: 'Sign Up',
                        onTap: () => _navigateTo(context, SignUpScreen()),
                      ),
                    if (!_vip)
                      _menuTile(
                        icon: Icons.workspace_premium,
                        label: 'Top up VIP',
                        onTap: () {
                          if (isSignedIn) {
                            _navigateTo(context, TopupScreen());
                          } else {
                            _showNeedSignInDialog(context, 'Top up VIP');
                          }
                        },
                      ),
                    _menuTile(
                      icon: Icons.workspace_premium,
                      label: 'Top up History',
                      onTap: () {
                        if (isSignedIn) {
                          _navigateTo(context, TopupHistoryScreen());
                        } else {
                          _showNeedSignInDialog(context, 'Top up History');
                        }
                      },
                    ),
                    _menuTile(
                      icon: Icons.contact_support,
                      label: 'Contact Us',
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final Uri url = Uri.parse('https://line.me/R/ti/p/@362odwuo');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Could not launch $url')),
                          );
                        }
                      },
                    ),
                    _menuTile(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () {
                        if (isSignedIn) {
                          _navigateTo(context, UserSettingsScreen());
                        } else {
                          _showNeedSignInDialog(context, 'Settings');
                        }
                      },
                    ),
                    if (isSignedIn)
                      _menuTile(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        onTap: () async {
                          _closeDrawerIfOpen(context);
                          final messenger = ScaffoldMessenger.of(context);
                          await signOutFromAllProviders();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('ออกจากระบบสำเร็จ')),
                          );
                        },
                      ),
                    if (_isAdmin && !_loadingRole)
                      _menuTile(
                        icon: Icons.engineering,
                        label: 'Developer',
                        onTap: () => _navigateTo(context, const AdminDashboard()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNeedSignInDialog(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('ยังไม่ได้เข้าสู่ระบบ', style: TextStyle(color: Colors.white)),
        content: Text(
          'กรุณาเข้าสู่ระบบก่อนใช้งาน "$actionName"',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }
}
