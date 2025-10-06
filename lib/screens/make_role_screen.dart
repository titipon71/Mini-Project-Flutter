import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class MakeRoleScreen extends StatefulWidget {
  const MakeRoleScreen({super.key});

  @override
  State<MakeRoleScreen> createState() => _MakeRoleScreenState();
}

class _MakeRoleScreenState extends State<MakeRoleScreen> {
  final _emailController = TextEditingController();
  final _uidController = TextEditingController();
  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _users = [];

  final List<Map<String, String>> _roles = [
    {'value': 'user', 'label': 'User (ผู้ใช้ทั่วไป)', 'color': '0xFF4CAF50'},
    {'value': 'vip', 'label': 'VIP (สมาชิกพรีเมียม)', 'color': '0xFFFF9800'},
    {'value': 'admin', 'label': 'Admin (ผู้ดูแลระบบ)', 'color': '0xFFF44336'},
  ];

  final _call = FirebaseFunctions.instance.httpsCallable('setUserRole');

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  // โหลดรายชื่อผู้ใช้ทั้งหมด
  Future<void> _loadAllUsers() async {
    setState(() => _isSearching = true);
    
    try {
      final ref = FirebaseDatabase.instance.ref('users');

      final snapshot = await ref.get();
      
      if (snapshot.exists) {
        final data = snapshot.value;
        List<Map<String, dynamic>> userList = [];
        
        if (data is Map) {
          data.forEach((uid, userData) {
            if (userData is Map) {
              userList.add({
                'uid': uid,
                'email': userData['email'] ?? '',
                'displayName': userData['displayName'] ?? '',
                'role': userData['role'] ?? 'user',
                'photoURL': userData['photoURL'],
                'createdAt': userData['createdAt'],
              });
            }
          });
        }
        
        // เรียงตามวันที่สร้าง (ใหม่ล่าสุดก่อน)
        userList.sort((a, b) {
          final aTime = a['createdAt'] ?? 0;
          final bTime = b['createdAt'] ?? 0;
          return bTime.compareTo(aTime);
        });
        
        setState(() {
          _users = userList;
        });
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // เปลี่ยน Role ของผู้ใช้
  Future<void> _changeUserRole(String uid, String newRole) async {
    setState(() => _isLoading = true);
    
    try {
      final res = await _call.call({
        'uid': uid,
        'role': newRole,
      });
      
      if (res.data['ok'] == true) {
        // อัปเดทใน Realtime Database ด้วย
        final ref = FirebaseDatabase.instance.ref('users/$uid');
        
        await ref.update({
          'role': newRole,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        
        _showSnackBar('เปลี่ยน Role สำเร็จ');
        _loadAllUsers(); // รีโหลดข้อมูล
      } else {
        _showSnackBar('เกิดข้อผิดพลาด: ${res.data['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ค้นหาผู้ใช้ตาม email หรือ UID
  List<Map<String, dynamic>> _getFilteredUsers(String query) {
    if (query.isEmpty) return _users;
    
    return _users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final uid = user['uid']?.toString().toLowerCase() ?? '';
      final displayName = user['displayName']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      
      return email.contains(searchQuery) || 
             uid.contains(searchQuery) || 
             displayName.contains(searchQuery);
    }).toList();
  }

  Color _getRoleColor(String role) {
    final roleData = _roles.firstWhere(
      (r) => r['value'] == role,
      orElse: () => _roles[0],
    );
    return Color(int.parse(roleData['color']!));
  }

  String _getRoleLabel(String role) {
    final roleData = _roles.firstWhere(
      (r) => r['value'] == role,
      orElse: () => _roles[0],
    );
    return roleData['label']!;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('เปลี่ยน Role ผู้ใช้', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ผู้ใช้: ${user['email']}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Role ปัจจุบัน: ${_getRoleLabel(user['role'])}',
              style: TextStyle(color: _getRoleColor(user['role'])),
            ),
            const SizedBox(height: 16),
            const Text('เลือก Role ใหม่:', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            ..._roles.map((role) {
              return RadioListTile<String>(
                title: Text(
                  role['label']!,
                  style: TextStyle(color: Color(int.parse(role['color']!))),
                ),
                value: role['value']!,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                  Navigator.of(context).pop();
                  _showChangeRoleDialog(user); // รีเฟรช dialog
                },
                activeColor: Color(int.parse(role['color']!)),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: user['role'] == _selectedRole ? null : () {
              Navigator.of(context).pop();
              _changeUserRole(user['uid'], _selectedRole);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRoleColor(_selectedRole),
              foregroundColor: Colors.white,
            ),
            child: const Text('เปลี่ยน Role'),
          ),
        ],
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
          // ช่องค้นหา
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
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {}); // รีเฟรชรายการ
              },
            ),
          ),

          // สถิติ
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('ทั้งหมด', _users.length.toString(), Colors.blue),
                _buildStatCard('User', _users.where((u) => u['role'] == 'user').length.toString(), Colors.green),
                _buildStatCard('VIP', _users.where((u) => u['role'] == 'vip').length.toString(), Colors.orange),
                _buildStatCard('Admin', _users.where((u) => u['role'] == 'admin').length.toString(), Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // รายการผู้ใช้
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : ListView.builder(
                    itemCount: _getFilteredUsers(_emailController.text).length,
                    itemBuilder: (context, index) {
                      final user = _getFilteredUsers(_emailController.text)[index];
                      final roleColor = _getRoleColor(user['role']);
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                      errorBuilder: (context, error, stackTrace) {
                                        return Text(
                                          (user['email'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        );
                                      },
                                    ),
                                  )
                                : Text(
                                    (user['email'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                          ),
                          title: Text(
                            user['displayName']?.isNotEmpty == true 
                                ? user['displayName'] 
                                : user['email'] ?? 'ไม่มีชื่อ',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user['displayName']?.isNotEmpty == true)
                                Text(user['email'] ?? '', style: const TextStyle(color: Colors.white70)),
                              Text(
                                'Role: ${_getRoleLabel(user['role'])}',
                                style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user['role'].toString().toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _isLoading ? null : () {
                                  _selectedRole = user['role'];
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
        Text(
          count,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
