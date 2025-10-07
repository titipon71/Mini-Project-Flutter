import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TopupHistoryScreen extends StatefulWidget {
  const TopupHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends State<TopupHistoryScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // ตัวกรองสถานะ
  final List<String> _statusOptions = ['ทั้งหมด', 'pending', 'paid', 'rejected', 'expired'];
  String _selectedStatus = 'ทั้งหมด';

  Query<Map<String, dynamic>> _baseQuery() {
    if (user == null) {
      // จะไม่ถูกใช้ (เราเช็กก่อนใน build)
      return FirebaseFirestore.instance.collection('users').doc('x').collection('topups');
    }
    var q = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('topups')
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'ทั้งหมด') {
      q = q.where('status', isEqualTo: _selectedStatus);
    }
    return q.limit(100); // ปรับตามต้องการ
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate().toLocal();
    // yyyy-MM-dd HH:mm
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
    // ถ้าอยากสวยขึ้น ใช้แพ็กเกจ intl ก็ได้
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คัดลอกแล้ว')));
  }

  void _showSlip(BuildContext context, Map<String, dynamic>? slip) {
    final url = slip?['downloadUrl'] as String?;
    final fileName = slip?['fileName'] as String? ?? 'slip.png';
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่มีสลิปแนบ')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: () => _copy(url),
                      tooltip: 'คัดลอกลิงก์',
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.white70),
                      onPressed: () {
                        // เปิดในเบราว์เซอร์ (เฉพาะเว็บจะเด่น, มือถือส่วนใหญ่ระบบจะเปิด viewer)
                        // ใช้ url_launcher ก็ได้ถ้าคุณมี (ไม่บังคับตรงนี้)
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) {
                      return const Center(child: Text('แสดงภาพไม่สำเร็จ', style: TextStyle(color: Colors.white70)));
                    }),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        const SizedBox(width: 12),
        const Icon(Icons.history, color: Colors.white70),
        const SizedBox(width: 8),
        const Text('ประวัติการเติมเงิน', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedStatus,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            items: _statusOptions
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s == 'ทั้งหมด' ? 'ทั้งหมด' : s,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val ?? 'ทั้งหมด'),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('ประวัติการเติมเงิน', style: TextStyle(color: Colors.white)) ,foregroundColor: Colors.white,),
        body: const Center(
          child: Text('กรุณาเข้าสู่ระบบก่อน', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ประวัติการเติมเงิน', style: TextStyle(color: Colors.white)) ,foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildFilterBar(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snap.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีประวัติการเติมเงิน', style: TextStyle(color: Colors.white54)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Stream จะอัปเดตให้เองอยู่แล้ว แค่ดีด setState ให้รู้สึกรีเฟรช
                    setState(() {});
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final topupId = (data['topupId'] ?? docs[i].id) as String;
                      final status = (data['status'] ?? '-') as String;
                      final amount = (data['amount'] ?? 0).toDouble();
                      final priceText = (data['priceText'] ?? '฿0') as String;
                      final label = (data['packageLabel'] ?? '-') as String;
                      final method = (data['paymentMethod'] ?? '-') as String;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final slip = (data['slip'] as Map?)?.cast<String, dynamic>();

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // แถวบน: id + ปุ่ม copy + สถานะ
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_long, size: 18, color: Colors.white70),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '#$topupId',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                                          onPressed: () => _copy(topupId),
                                          tooltip: 'คัดลอกหมายเลขออเดอร์',
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.15),
                                      border: Border.all(color: _statusColor(status).withOpacity(0.35)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // รายละเอียดหลัก
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _kv('แพ็กเกจ', label),
                                        _kv('ราคา', priceText),
                                        _kv('วิธีชำระ', method),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('ยอดชำระ', style: TextStyle(color: Colors.white60)),
                                      Text(
                                        '฿${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // วันที่สร้าง
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 16, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Text(_fmtDate(createdAt), style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // ปุ่มการกระทำ
                              Row(
                                children: [
                                  if (slip != null && slip['downloadUrl'] != null)
                                    TextButton.icon(
                                      onPressed: () => _showSlip(context, slip),
                                      icon: const Icon(Icons.image, color: Colors.white70),
                                      label: const Text('ดูสลิป', style: TextStyle(color: Colors.white)),
                                    ),
                                  const Spacer(),
                                  // ที่ว่างสำหรับปุ่มอื่นๆ เช่น ออกใบเสร็จ, ติดต่อแอดมิน ฯลฯ
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(k, style: const TextStyle(color: Colors.white60))),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
