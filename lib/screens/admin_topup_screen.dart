import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Twebtoon/services/api_service.dart';

class AdminTopupScreen extends StatefulWidget {
  const AdminTopupScreen({Key? key}) : super(key: key);

  @override
  State<AdminTopupScreen> createState() => _AdminTopupScreenState();
}

class _AdminTopupScreenState extends State<AdminTopupScreen> {
  final _statusOptions = const ['ทั้งหมด', 'pending', 'paid', 'rejected'];

  String _selectedStatus = 'ทั้งหมด';
  String _search = '';
  int _skip = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 30;

  final List<Map<String, dynamic>> _buffer = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _buffer.clear();
      _skip = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      var url = '/api/v1/admin/topups?limit=$_pageSize&skip=$_skip';
      if (_selectedStatus != 'ทั้งหมด') url += '&topup_status=$_selectedStatus';

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (items.isNotEmpty) {
          _buffer.addAll(items);
          _skip += items.length;
          _hasMore = items.length == _pageSize;
        } else {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (_) {
      _hasMore = false;
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  List<Map<String, dynamic>> _filtered() {
    if (_search.trim().isEmpty) return _buffer;
    final key = _search.trim().toLowerCase();
    return _buffer.where((data) {
      final tid = (data['topupId'] ?? data['id'] ?? '').toString().toLowerCase();
      final uid = (data['userId'] ?? '').toString().toLowerCase();
      final name = (data['userName'] ?? '').toString().toLowerCase();
      return tid.contains(key) || uid.contains(key) || name.contains(key);
    }).toList();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('คัดลอกแล้ว')));
  }

  void _showSlip(Map<String, dynamic>? slip) {
    final url = slip?['downloadUrl'] as String?;
    final fileName = slip?['fileName'] as String? ?? 'slip.png';
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: url == null ? null : () => _copy(url),
                      tooltip: 'คัดลอกลิงก์',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (url != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Text('แสดงภาพไม่สำเร็จ', style: TextStyle(color: Colors.white70)),
                          );
                        },
                      ),
                    ),
                  )
                else
                  const Text('ไม่มีสลิปแนบ', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _updateStatus({required String topupId, required String newStatus}) async {
    try {
      final response = await ApiService.patch(
        '/api/v1/admin/topups/$topupId',
        {'status': newStatus},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตสถานะ #$topupId → $newStatus สำเร็จ')),
        );
        await _loadInitial();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตไม่สำเร็จ (${response.statusCode})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndUpdate(
      String actionName, String newStatus, String topupId, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('ยืนยัน$actionName?', style: const TextStyle(color: Colors.white)),
        content: Text('ออเดอร์ #$topupId จะถูกเปลี่ยนสถานะเป็น "$newStatus"',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _updateStatus(topupId: topupId, newStatus: newStatus);
    }
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.admin_panel_settings, color: Colors.white70),
              SizedBox(width: 8),
              Text('แอดมิน: จัดการคำสั่งเติมเงิน',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'ค้นหา topupId / userId / name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54, size: 18),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
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
                  onChanged: (v) async {
                    setState(() => _selectedStatus = v ?? 'ทั้งหมด');
                    await _loadInitial();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Admin • Topups', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                    !_isLoadingMore) {
                  _loadMore();
                }
                return false;
              },
              child: _buildList(),
            ),
          ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered();
    if (items.isEmpty && !_isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('ไม่พบรายการ', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final data = items[i];
        final topupId = (data['topupId'] ?? data['id'] ?? '-').toString();
        final uid = (data['userId'] ?? '-').toString();
        final name = (data['userName'] ?? '-').toString();
        final status = (data['status'] ?? '-').toString();
        final label = (data['packageLabel'] ?? '-').toString();
        final priceText = (data['priceText'] ?? '-').toString();
        final amount = ((data['amount'] ?? 0) as num).toDouble();
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
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 18, color: Colors.white70),
                          GestureDetector(
                            onLongPress: () => _copy(topupId),
                            child: Text('#$topupId',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.person, size: 18, color: Colors.white54),
                          GestureDetector(
                            onLongPress: () => _copy(uid),
                            child: Text('$name ($uid)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.15),
                        border:
                            Border.all(color: _statusColor(status).withOpacity(0.35)),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.white),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _kv('แพ็กเกจ', label),
                            _kv('ราคา', priceText),
                            _kv('วิธี', method),
                            _kv('สร้างเมื่อ', _fmtDate(createdAt)),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('ยอดชำระ', style: TextStyle(color: Colors.white60)),
                        Text('฿${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showSlip(slip),
                      icon: const Icon(Icons.image, color: Colors.white70),
                      label: const Text('ดูสลิป', style: TextStyle(color: Colors.white)),
                    ),
                    const Spacer(),
                    if (status != 'paid' && status != 'rejected')
                      ElevatedButton.icon(
                        onPressed: () =>
                            _confirmAndUpdate('อนุมัติ', 'paid', topupId, uid),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label:
                            const Text('อนุมัติ', style: TextStyle(color: Colors.white)),
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    const SizedBox(width: 8),
                    if (status != 'rejected' && status != 'paid')
                      ElevatedButton.icon(
                        onPressed: () =>
                            _confirmAndUpdate('ปฏิเสธ', 'rejected', topupId, uid),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label:
                            const Text('ปฏิเสธ', style: TextStyle(color: Colors.white)),
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
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
