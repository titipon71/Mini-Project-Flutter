import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Twebtoon/services/api_service.dart';

class TopupHistoryScreen extends StatefulWidget {
  const TopupHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends State<TopupHistoryScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  final List<String> _statusOptions = ['ทั้งหมด', 'pending', 'paid', 'rejected', 'expired'];
  String _selectedStatus = 'ทั้งหมด';

  List<Map<String, dynamic>> _topups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTopups();
  }

  Future<void> _loadTopups() async {
    if (_user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var url = '/api/v1/me/topups?limit=100';
      if (_selectedStatus != 'ทั้งหมด') url += '&topup_status=$_selectedStatus';
      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _topups = items; _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'โหลดข้อมูลไม่สำเร็จ (${response.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.redAccent;
      case 'expired': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่มีสลิปแนบ')));
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
                      child: Text(fileName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: () => _copy(url),
                      tooltip: 'คัดลอกลิงก์',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(url, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                      return const Center(
                          child: Text('แสดงภาพไม่สำเร็จ',
                              style: TextStyle(color: Colors.white70)));
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
        const Text('ประวัติการเติมเงิน',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedStatus,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            items: _statusOptions
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedStatus = val ?? 'ทั้งหมด');
              _loadTopups();
            },
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('ประวัติการเติมเงิน',
              style: TextStyle(color: Colors.white)),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child:
              Text('กรุณาเข้าสู่ระบบก่อน', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ประวัติการเติมเงิน',
            style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildFilterBar(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text('เกิดข้อผิดพลาด: $_error',
            style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (_topups.isEmpty) {
      return const Center(
        child: Text('ยังไม่มีประวัติการเติมเงิน',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTopups,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _topups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final data = _topups[i];
          final topupId = (data['topupId'] ?? data['id'] ?? '-').toString();
          final status = (data['status'] ?? '-').toString();
          final amount = ((data['amount'] ?? 0) as num).toDouble();
          final priceText = (data['priceText'] ?? '฿0').toString();
          final label = (data['packageLabel'] ?? '-').toString();
          final method = (data['paymentMethod'] ?? '-').toString();
          final createdAt = data['createdAt'] as String?;
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
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                size: 18, color: Colors.white70),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('#$topupId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  size: 16, color: Colors.white54),
                              onPressed: () => _copy(topupId),
                              tooltip: 'คัดลอกหมายเลขออเดอร์',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          border: Border.all(
                              color: _statusColor(status).withOpacity(0.35)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          const Text('ยอดชำระ',
                              style: TextStyle(color: Colors.white60)),
                          Text('฿${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(_fmtDate(createdAt),
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (slip != null && slip['downloadUrl'] != null)
                        TextButton.icon(
                          onPressed: () => _showSlip(context, slip),
                          icon: const Icon(Icons.image, color: Colors.white70),
                          label: const Text('ดูสลิป',
                              style: TextStyle(color: Colors.white)),
                        ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(k, style: const TextStyle(color: Colors.white60))),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
