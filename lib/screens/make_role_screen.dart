import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Twebtoon/services/api_service.dart';

class MakeRoleScreen extends StatefulWidget {
  const MakeRoleScreen({super.key});

  @override
  State<MakeRoleScreen> createState() => _MakeRoleScreenState();
}

class _MakeRoleScreenState extends State<MakeRoleScreen> {
  final _emailController = TextEditingController();
  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isAdmin = false;
  int _vipDays = 30;
  List<Map<String, dynamic>> _users = [];

  final List<Map<String, String>> _roles = [
    {'value': 'user', 'label': 'User (ผู้ใช้ทั่วไป)', 'color': '0xFF4CAF50'},
    {'value': 'vip', 'label': 'VIP (สมาชิกพรีเมียม)', 'color': '0xFFFF9800'},
    {'value': 'admin', 'label': 'Admin (ผู้ดูแลระบบ)', 'color': '0xFFF44336'},
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    try {
      final response = await ApiService.get('/api/v1/me/roles');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final isAdmin = json['admin'] == true;
        if (mounted) setState(() => _isAdmin = isAdmin);
        if (isAdmin) {
          await _loadAllUsers();
        } else {
          _showSnackBar('คุณไม่มีสิทธิ์แอดมิน');
        }
      }
    } catch (e) {
      _showSnackBar('ตรวจสอบสิทธิ์ไม่สำเร็จ: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    if (!_isAdmin) return;
    setState(() => _isSearching = true);
    try {
      final response = await ApiService.get('/api/v1/admin/users');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final users = (json['users'] as List<dynamic>).cast<Map<String, dynamic>>();
        users.sort((a, b) {
          final ta = DateTime.tryParse(a['createdAt'] ?? '')?.millisecondsSinceEpoch ?? 0;
          final tb = DateTime.tryParse(b['createdAt'] ?? '')?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        if (mounted) setState(() => _users = users);
      } else {
        _showSnackBar('โหลดรายชื่อผู้ใช้ไม่สำเร็จ');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _changeUserRole(String uid, String newRole) async {
    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{'role': newRole};
      if (newRole == 'vip') body['durationDays'] = _vipDays;

      final response = await ApiService.patch('/api/v1/admin/users/$uid/roles', body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSnackBar('เปลี่ยน Role สำเร็จ');
        await _loadAllUsers();
      } else {
        _showSnackBar('เปลี่ยน Role ไม่สำเร็จ (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredUsers(String query) {
    if (query.isEmpty) return _users;
    return _users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final uid = user['uid']?.toString().toLowerCase() ?? '';
      final displayName = user['displayName']?.toString().toLowerCase() ?? '';
      final q = query.toLowerCase();
      return email.contains(q) || uid.contains(q) || displayName.contains(q);
    }).toList();
  }

  Color _getRoleColor(String role) {
    final roleData = _roles.firstWhere((r) => r['value'] == role, orElse: () => _roles[0]);
    return Color(int.parse(roleData['color']!));
  }

  String _getRoleLabel(String role) {
    final roleData = _roles.firstWhere((r) => r['value'] == role, orElse: () => _roles[0]);
    return roleData['label']!;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _fmtVipUntil(dynamic vipUntil) {
    if (vipUntil == null) return '';
    final dt = DateTime.tryParse(vipUntil.toString())?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  bool _vipActive(dynamic vipUntil) {
    if (vipUntil == null) return false;
    final dt = DateTime.tryParse(vipUntil.toString());
    return dt != null && dt.isAfter(DateTime.now());
  }

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    final daysController = TextEditingController(text: _vipDays.toString());
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('เปลี่ยน Role ผู้ใช้', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ผู้ใช้: ${user['email']}',
                    style: const TextStyle(color: Colors.white70)),
                Text('Role ปัจจุบัน: ${_getRoleLabel(user['role'] ?? 'user')}',
                    style: TextStyle(color: _getRoleColor(user['role'] ?? 'user'))),
                const SizedBox(height: 16),
                const Text('เลือก Role ใหม่:', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                ..._roles.map((role) {
                  return RadioListTile<String>(
                    title: Text(role['label']!,
                        style: TextStyle(color: Color(int.parse(role['color']!)))),
                    value: role['value']!,
                    groupValue: _selectedRole,
                    onChanged: (value) {
                      setState(() => _selectedRole = value!);
                      setStateDialog(() {});
                    },
                    activeColor: Color(int.parse(role['color']!)),
                  );
                }),
                if (_selectedRole == 'vip') ...[
                  const SizedBox(height: 8),
                  const Text('จำนวนวัน VIP', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'เช่น 30',
                      hintStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) _vipDays = parsed;
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: (user['role'] ?? 'user') == _selectedRole
                    ? null
                    : () {
                        if (_selectedRole == 'vip') {
                          final parsed = int.tryParse(daysController.text);
                          if (parsed == null || parsed <= 0) {
                            _showSnackBar('กรุณากรอกจำนวนวันให้ถูกต้อง (> 0)');
                            return;
                          }
                          _vipDays = parsed;
                        }
                        Navigator.of(context).pop();
                        _changeUserRole(user['uid'], _selectedRole);
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _getRoleColor(_selectedRole),
                    foregroundColor: Colors.white),
                child: const Text('เปลี่ยน Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('จัดการ Role ผู้ใช้', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadAllUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วย Email, UID หรือชื่อ',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('ทั้งหมด', _users.length.toString(), Colors.blue),
                _buildStatCard('User',
                    _users.where((u) => u['role'] == 'user').length.toString(),
                    Colors.green),
                _buildStatCard(
                    'VIP',
                    _users.where((u) => u['role'] == 'vip').length.toString(),
                    Colors.orange),
                _buildStatCard(
                    'Admin',
                    _users.where((u) => u['role'] == 'admin').length.toString(),
                    Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : ListView.builder(
                    itemCount: _getFilteredUsers(_emailController.text).length,
                    itemBuilder: (context, index) {
                      final user =
                          _getFilteredUsers(_emailController.text)[index];
                      final role = (user['role'] ?? 'user') as String;
                      final roleColor = _getRoleColor(role);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        color: Colors.grey[800],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: roleColor,
                            child: user['photoURL'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      user['photoURL'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        (user['email'] ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                : Text(
                                    (user['email'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                          title: Text(
                            (user['displayName']?.toString().isNotEmpty == true)
                                ? user['displayName']
                                : user['email'] ?? 'ไม่มีชื่อ',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user['displayName']?.toString().isNotEmpty == true)
                                Text(user['email'] ?? '',
                                    style: const TextStyle(color: Colors.white70)),
                              Text('Role: ${_getRoleLabel(role)}',
                                  style: TextStyle(
                                      color: roleColor, fontWeight: FontWeight.bold)),
                              if (role == 'vip' && _vipActive(user['vipUntil']))
                                Text('หมดอายุ: ${_fmtVipUntil(user['vipUntil'])}',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: roleColor,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(role.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        _selectedRole = role;
                                        _showChangeRoleDialog(user);
                                      },
                                icon: const Icon(Icons.edit, color: Colors.white70),
                                tooltip: 'เปลี่ยน Role',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Column(
      children: [
        Text(count,
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
