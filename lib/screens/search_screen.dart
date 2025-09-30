import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final Set<String> _filters = {'ทั้งหมด'};
  final _chips = const ['ทั้งหมด', 'ยอดนิยม', 'ล่าสุด', 'ที่บันทึกไว้'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ค้นหา...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _chips[index];
                final selected = _filters.contains(label);
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (label == 'ทั้งหมด') {
                        _filters
                          ..clear()
                          ..add('ทั้งหมด');
                      } else {
                        _filters.remove('ทั้งหมด');
                        if (selected) {
                          _filters.remove(label);
                          if (_filters.isEmpty) _filters.add('ทั้งหมด');
                        } else {
                          _filters.add(label);
                        }
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Results / Empty state
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: query.isEmpty
                  ? _EmptyState(onUseSample: () {
                      _controller.text = 'ตัวอย่าง';
                      setState(() {});
                    })
                  : ListView.builder(
                      key: ValueKey(query + _filters.join(',')),
                      itemCount: 7,
                      itemBuilder: (context, index) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.article),
                          ),
                          title: Text('$query - ผลลัพธ์ที่ ${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('ฟิลเตอร์: ${_filters.join(", ")}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUseSample});
  final VoidCallback onUseSample;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const ValueKey('empty'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text('ลองพิมพ์เพื่อค้นหา',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('หรือใช้ตัวอย่างการค้นหา'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onUseSample,
            icon: const Icon(Icons.lightbulb),
            label: const Text('ใช้ตัวอย่าง'),
          ),
        ],
      ),
    );
  }
}
