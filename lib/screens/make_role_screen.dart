  import 'dart:async';

  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:cloud_functions/cloud_functions.dart';
  // import 'package:firebase_core/firebase_core.dart';

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
    final _fs = FirebaseFirestore.instance; // 🔹 เพิ่ม Firestore

    final List<Map<String, String>> _roles = [
      {'value': 'user', 'label': 'User (ผู้ใช้ทั่วไป)', 'color': '0xFF4CAF50'},
      {'value': 'vip', 'label': 'VIP (สมาชิกพรีเมียม)', 'color': '0xFFFF9800'},
      {'value': 'admin', 'label': 'Admin (ผู้ดูแลระบบ)', 'color': '0xFFF44336'},
    ];

    late final FirebaseFunctions functions; // << แทนตัวแปร global
    StreamSubscription<User?>? _tokenSub; // << เก็บ subscription
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    _myUserDocSub; // optional

    @override
    void initState() {
      super.initState();
      functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

      _tokenSub = FirebaseAuth.instance.idTokenChanges().listen((user) async {
        if (!mounted) return;
        if (user == null) {
          setState(() {
            _users = [];
            _isAdmin = false;
          });
          _myUserDocSub?.cancel();
          return;
        }

        final token = await user.getIdTokenResult(true);
        final isAdmin =
            (token.claims?['admin'] == true) ||
            (token.claims?['role'] == 'admin');
        setState(() => _isAdmin = isAdmin);

        // (ออปชัน) ฟังเอกสาร users/{myUid} แบบ realtime เผื่อมี field อื่นที่อยากอัปเดต UI
        _myUserDocSub?.cancel();
        _myUserDocSub = _fs.collection('users').doc(user.uid).snapshots().listen((
          _,
        ) {
          // ถ้าต้องอัปเดตบางอย่างใน UI ก็ setState ได้ที่นี่
        });

        if (isAdmin) {
          _loadAllUsers();
        } else {
          setState(() => _users = []);
          _showSnackBar('คุณไม่มีสิทธิ์แอดมิน');
        }
      });
    }

    @override
    void dispose() {
      _tokenSub?.cancel();
      _myUserDocSub?.cancel();
      _emailController.dispose();
      super.dispose();
    }

    Future<Map<String, Map<String, dynamic>>> _fetchUserDocsByUids(
      List<String> uids,
    ) async {
      final Map<String, Map<String, dynamic>> out = {};
      const chunk = 20;
      for (var i = 0; i < uids.length; i += chunk) {
        final part = uids.sublist(
          i,
          i + chunk > uids.length ? uids.length : i + chunk,
        );
        final snap = await _fs
            .collection('users')
            .where(FieldPath.documentId, whereIn: part)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          out[doc.id] = data;
        }
      }
      return out;
    }

    // โหลดรายชื่อผู้ใช้ทั้งหมด
    Future<void> _loadAllUsers() async {
      if (!_isAdmin) return;
      setState(() => _isSearching = true);
      try {
        final listUsersFn = functions.httpsCallable('listUsers');
        final res = await listUsersFn.call();

        if (res.data['ok'] == true) {
          final List raw = (res.data['users'] ?? []) as List;

          // 1) map จาก Auth (ยังใช้สำหรับดู createdAt และ fallback)
          final List<Map<String, dynamic>> fromAuth = raw
              .map<Map<String, dynamic>>((u) {
                final m = (u as Map);
                final claims = (m['claims'] ?? {}) as Map;

                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final isAdminClaim =
                    claims['admin'] == true || claims['role'] == 'admin';

                // vip จาก claims (fallback เท่านั้น)
                final vipUntilClaim = (claims['vipUntil'] is num)
                    ? (claims['vipUntil'] as num).toInt()
                    : 0;
                final vipValidClaim =
                    (claims['vip'] == true) && vipUntilClaim > nowMs;

                String roleFromClaims;
                if (isAdminClaim) {
                  roleFromClaims = 'admin';
                } else if (vipValidClaim) {
                  roleFromClaims = 'vip';
                } else {
                  roleFromClaims = 'user';
                }

                final createdAtIso = m['createdAt'] as String?;
                final createdAtMillis =
                    DateTime.tryParse(
                      createdAtIso ?? '',
                    )?.millisecondsSinceEpoch ??
                    0;

                return {
                  'uid': m['uid'] ?? '',
                  'email': m['email'] ?? '',
                  'displayName': m['displayName'] ?? '',
                  'photoURL': m['photoURL'],
                  'createdAt': createdAtMillis,
                  // ชั่วคราวจาก claims — เดี๋ยว Firestore จะทับ
                  'role': roleFromClaims,
                  'vipUntil': vipUntilClaim,
                };
              })
              .toList();

          // 2) โหลด Firestore users/{uid} แล้ว override
  final uids = fromAuth
      .map((e) => e['uid'] as String)
      .where((s) => s.isNotEmpty)
      .toList();
  final userDocs = await _fetchUserDocsByUids(uids); // Map<uid, data>

  int _tsToMs(dynamic ts) {
    try {
      // รองรับทั้ง Timestamp ของ Firestore และ number ที่เป็น millis
      if (ts == null) return 0;
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      if (ts is num) return ts.toInt();
    } catch (_) {}
    return 0;
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;

  final merged = fromAuth.map((row) {
    final uid = row['uid'] as String;
    final f = userDocs[uid];

    if (f == null) return row; // ไม่มี doc ก็ใช้ของเดิมจาก Auth

    final mergedRow = Map<String, dynamic>.from(row);

    // ---------- อ่านจาก Firestore: users/{uid}.roles ----------
    final roles = f['roles'];
    if (roles is Map) {
      final bool isAdminFs = roles['admin'] == true;
      final bool isVipFs   = roles['vip'] == true;
      final int  vipUntilMsFs = _tsToMs(roles['vipUntil']);

      // กำหนด role จาก Firestore เป็นหลัก
      if (isAdminFs) {
        mergedRow['role'] = 'admin';
      } else if (isVipFs && vipUntilMsFs > nowMs) {
        mergedRow['role'] = 'vip';
      } else {
        mergedRow['role'] = 'user';
      }

      // เก็บ vipUntil (ms) ไว้ใช้แสดงผล
      mergedRow['vipUntil'] = vipUntilMsFs;
    }

    // ---------- โปรไฟล์อื่น ๆ (ถ้ามีใน users/{uid}) ----------
    if (f['displayName'] is String && (f['displayName'] as String).isNotEmpty) {
      mergedRow['displayName'] = f['displayName'];
    }
    if (f['photoURL'] is String && (f['photoURL'] as String).isNotEmpty) {
      mergedRow['photoURL'] = f['photoURL'];
    }

    return mergedRow;
  }).toList();

  merged.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
  setState(() => _users = merged);


          merged.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
          );
          setState(() => _users = merged);
        } else {
          _showSnackBar('โหลดรายชื่อผู้ใช้ไม่สำเร็จ');
        }
      } on FirebaseFunctionsException catch (e) {
        _showSnackBar('โหลดผู้ใช้ล้มเหลว: ${e.code} ${e.message ?? ''}');
      } catch (e) {
        _showSnackBar('เกิดข้อผิดพลาด: $e');
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    }

    // เปลี่ยน Role ของผู้ใช้
    Future<void> _changeUserRole(String uid, String newRole) async {
      setState(() => _isLoading = true);
      try {
        final setUserRoleFn = functions.httpsCallable('setUserRole');
        final Map<String, dynamic> payload = {'uid': uid, 'role': newRole};
        if (newRole == 'vip') {
          payload['durationDays'] = _vipDays; // ใช้ค่าจาก TextField
          payload['extend'] = true; // ถ้าอยากให้ต่ออายุจากของเดิม (ถ้า Function รองรับ)
        }

        final res = await setUserRoleFn.call(payload);
        print('setUserRole result: ${res.data}');

        if (res.data['ok'] == true) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          if (currentUid != null && currentUid == uid) {
            await FirebaseAuth.instance.currentUser?.getIdToken(true);
          }
          _showSnackBar('เปลี่ยน Role สำเร็จ');
          await _loadAllUsers();
        } else {
          _showSnackBar(
            'เกิดข้อผิดพลาด: ${res.data['error'] ?? 'Unknown error'}',
          );
        }
      } on FirebaseFunctionsException catch (e) {
        _showSnackBar('เปลี่ยน Role ล้มเหลว: ${e.code} ${e.message ?? ''}');
      } catch (e) {
        _showSnackBar('เกิดข้อผิดพลาด: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    void _showChangeRoleDialog(Map<String, dynamic> user) {
      final daysController = TextEditingController(text: _vipDays.toString());

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'เปลี่ยน Role ผู้ใช้',
                style: TextStyle(color: Colors.white),
              ),
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
                  const Text(
                    'เลือก Role ใหม่:',
                    style: TextStyle(color: Colors.white),
                  ),
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
                        setStateDialog(() {}); // รีเฟรชเฉพาะใน dialog
                      },
                      activeColor: Color(int.parse(role['color']!)),
                    );
                  }).toList(),

                  // ----- ช่องกรอกจำนวนวัน: แสดงเฉพาะตอนเลือก VIP -----
                  if (_selectedRole == 'vip') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'จำนวนวัน VIP',
                      style: TextStyle(color: Colors.white),
                    ),
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
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          _vipDays = parsed;
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: user['role'] == _selectedRole
                      ? null
                      : () {
                          // validation เบื้องต้น
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
                    foregroundColor: Colors.white,
                  ),
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
          title: const Text(
            'จัดการ Role ผู้ใช้',
            style: TextStyle(color: Colors.white),
          ),
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
                  _buildStatCard(
                    'ทั้งหมด',
                    _users.length.toString(),
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'User',
                    _users.where((u) => u['role'] == 'user').length.toString(),
                    Colors.green,
                  ),
                  _buildStatCard(
                    'VIP',
                    _users.where((u) => u['role'] == 'vip').length.toString(),
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Admin',
                    _users.where((u) => u['role'] == 'admin').length.toString(),
                    Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // รายการผู้ใช้
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ListView.builder(
                      itemCount: _getFilteredUsers(_emailController.text).length,
                      itemBuilder: (context, index) {
                        final user = _getFilteredUsers(
                          _emailController.text,
                        )[index];
                        final roleColor = _getRoleColor(user['role']);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
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
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Text(
                                                (user['email'] ?? 'U')[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Text(
                                      (user['email'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            title: Text(
                              user['displayName']?.isNotEmpty == true
                                  ? user['displayName']
                                  : user['email'] ?? 'ไม่มีชื่อ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user['displayName']?.isNotEmpty == true)
                                  Text(
                                    user['email'] ?? '',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                Text(
                                  'Role: ${_getRoleLabel(user['role'])}',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (user['role'] == 'vip' &&
                                    (user['vipUntil'] ?? 0) >
                                        DateTime.now().millisecondsSinceEpoch)
                                  Text(
                                    'หมดอายุ: ${DateTime.fromMillisecondsSinceEpoch(user['vipUntil']).toLocal()}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
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
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          _selectedRole = user['role'];
                                          _showChangeRoleDialog(user);
                                        },
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                  ),
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      );
    }
  }
