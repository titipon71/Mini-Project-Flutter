import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:my_app/assets/widgets/example_sidebarx.dart';
import 'package:my_app/screens/home2_screen.dart';
import 'package:my_app/screens/navbar2_screen.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:step_progress/step_progress.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thaiqr/thaiqr.dart';
import 'dart:html' as html;

class SubscriptionOption {
  final String label;
  final String price;
  final int value;
  final String? tag;

  SubscriptionOption(this.label, this.price, this.value, {this.tag});
}

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  final GlobalKey _qrKey = GlobalKey();
  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  final stepProgressController = StepProgressController(
    totalSteps: 3,
    initialStep: 0,
  );
  final myColor = const Color(0xFFF6B606); // แก้ไขการประกาศตัวแปร
  double _parsePrice(String priceText) {
    return double.tryParse(priceText.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  User? user = FirebaseAuth.instance.currentUser;

  // เลือกแพ็กเกจ
  int selectedValue = -1;

  // ข้อมูลองค์ประกอบสำหรับหน้า Review
  String? get userId => user?.uid;
  String? get userName => user?.displayName;
  String? referral = "";

  // วิธีชำระเงิน
  int selectedPayment = -1; // 0 = PromptPay, 1 = บัตรเครดิต, 2 = โอนเงิน
  bool agreeTnC = false;

  // ถ้าต้องการรู้ current step จาก controller ให้ลองฟัง listener
  int currentStep = 0;

  Future<void> _saveQrToGallery() async {
  try {
    // 🔹 1. แปลง Widget เป็น PNG bytes
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final filename = 'promptpay_${DateTime.now().millisecondsSinceEpoch}.png';

    // 🔹 2. แยกตาม Platform
    if (kIsWeb) {
      // ======= 🌐 WEB =======
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);

      _showSnack('✅ ดาวน์โหลด QR เรียบร้อย');
    } else {
      // ======= 📱 MOBILE =======
      // ขอ permission สำหรับ Android (ไม่บังคับใน iOS)
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnack('ไม่ได้รับสิทธิ์บันทึกไฟล์');
        return;
      }

      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: filename,
        quality: 100,
      );

      final ok = (result is Map) && (result['isSuccess'] == true || result['filePath'] != null);
      _showSnack(ok ? '✅ บันทึก QR ลงแกลเลอรีแล้ว' : '❌ บันทึกไม่สำเร็จ');
    }
  } catch (e) {
    _showSnack('เกิดข้อผิดพลาด: $e');
  }
}


  final List<SubscriptionOption> options = [
    SubscriptionOption("2 วัน", "฿99", 0),
    SubscriptionOption("7 วัน", "฿189", 1, tag: "สุดคุ้ม (-50%)"),
    SubscriptionOption("15 วัน", "฿299", 2),
    SubscriptionOption("30 วัน", "฿389", 3, tag: "ยอดนิยม"),
    SubscriptionOption("45 วัน", "฿599", 4),
    SubscriptionOption("60 วัน", "฿769", 5),
    SubscriptionOption("12 เดือน", "฿4399", 6),
  ];

  /// =============== EMV / Thai QR helpers ===============
  String _emv(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  // CRC16-CCITT (0xFFFF), poly 0x1021, no XOR-out
  int _crc16CCITT(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc ^= (b << 8) & 0xFFFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// แปลงเบอร์มือถือ 0XXXXXXXXX -> 0066XXXXXXXXX (ตัด 0 นำหน้า)
  String _promptPayMobile(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      return '0066${digits.substring(1)}';
    }
    if (digits.startsWith('66')) {
      return '00$digits';
    }
    // ถ้าเป็นรูปแบบอื่น ให้ผู้ใช้จัดรูปเองตามที่ใช้งานจริง
    return digits;
  }

  /// สร้าง Thai QR PromptPay Payload
  /// [ppId] = หมายเลขพร้อมเพย์ (เช่น มือถือ) ที่แปลงเป็นรูปแบบตามสเปคแล้ว
  /// [amountTHB] = จำนวนเงิน (เช่น 189.00) ถ้า null จะไม่ล็อกยอด (Static)
  /// [merchantName], [merchantCity], [reference] = optional
  String buildPromptPayPayload({
    required String ppId,
    double? amountTHB,
    String merchantName = 'MERCHANT',
    String merchantCity = 'BANGKOK',
    String? reference,
    bool dynamicQR = true,
  }) {
    final p00 = _emv('00', '01');
    final p01 = _emv('01', dynamicQR ? '12' : '11');

    final mai = _emv('00', 'A000000677010111') + _emv('01', ppId);
    final p29 = _emv('29', mai);

    final p52 = _emv('52', '0000');
    final p53 = _emv('53', '764');
    final p54 = amountTHB != null
        ? _emv('54', amountTHB.toStringAsFixed(2))
        : '';
    final p58 = _emv('58', 'TH');

    // ใช้ min() เพื่อได้ int แน่ ๆ
    final safeName = merchantName.substring(0, min(merchantName.length, 25));
    final safeCity = merchantCity.substring(0, min(merchantCity.length, 15));
    final p59 = _emv('59', safeName);
    final p60 = _emv('60', safeCity);

    String p62 = '';
    if (reference != null && reference.isNotEmpty) {
      final ref = _emv('05', reference);
      p62 = _emv('62', ref);
    }

    final noCRC =
        p00 + p01 + p29 + p52 + p53 + p54 + p58 + p59 + p60 + p62 + '6304';
    final bytes = ascii.encode(noCRC);
    final crc = _crc16CCITT(
      bytes,
    ).toRadixString(16).toUpperCase().padLeft(4, '0');
    final p63 = '63' + '04' + crc;

    return noCRC + p63;
  }

  @override
  void initState() {
    super.initState();
    // sync UI กับ StepProgressController (ถ้าแพ็กเกจรองรับ)
    stepProgressController.addListener(() {
      setState(() {
        currentStep = stepProgressController.currentStep;
      });
    });
  }

  SubscriptionOption? get selectedOption {
    if (selectedValue < 0) return null;
    return options.firstWhere((o) => o.value == selectedValue);
  }

  void goNext() {
    // validation ก่อนข้ามขั้น
    if (currentStep == 0) {
      if (selectedOption == null) {
        _showSnack("กรุณาเลือกแพ็กเกจ");
        return;
      }
    } else if (currentStep == 1) {
      // ตัวอย่าง validation หน้าตรวจสอบข้อมูล
      if (userId == null || userId!.isEmpty) {
        _showSnack("ไม่พบข้อมูลผู้ใช้ กรุณาลองใหม่อีกครั้ง");
        return;
      }
    }
    stepProgressController.nextStep();
  }

  void goPrevious() {
    stepProgressController.previousStep();
  }

  void payNow() {
    if (selectedPayment < 0) {
      _showSnack("กรุณาเลือกวิธีชำระเงิน");
      return;
    }

    if (selectedPayment == 0) {
      _showPromptPayQR(context); // แสดง QR เฉพาะกรณี PromptPay เท่านั้น
      return;
    }

    // กรณีอื่น ๆ (บัตร/โอน)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "ชำระเงินสำเร็จ",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "ขอบคุณสำหรับการชำระเงิน",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );

    // *** เอา “โค้ดสร้าง QR + แสดง Dialog QR” ออกจากบล็อกนี้ ***
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // String _paymentLabel(int val) {
  //   switch (val) {
  //     case 0:
  //       return "PromptPay";
  //     case 1:
  //       return "บัตรเครดิต/เดบิต";
  //     case 2:
  //       return "โอนเงินผ่านธนาคาร";
  //     default:
  //       return "-";
  //   }
  // }

  void _showPromptPayQR(BuildContext context) {
    final opt = selectedOption;
    if (opt == null) {
      _showSnack("กรุณาเลือกแพ็กเกจ");
      return;
    }

    final ppId = _promptPayMobile('0876947022');
    final payload = buildPromptPayPayload(
      ppId: ppId,
      amountTHB: _parsePrice(opt.price),
      merchantName: (userName ?? 'USER'),
      merchantCity: 'BANGKOK',
      reference: '${userId ?? ''}-${opt.value}',
      dynamicQR: true,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        actionsAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
        actionsOverflowButtonSpacing: 12, // ระยะห่างเมื่อพับบรรทัด
        actionsOverflowDirection:
            VerticalDirection.down, // ถ้าล้น ให้ขึ้นบรรทัดใหม่ลงล่าง
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        backgroundColor: Colors.grey[900],
        title: const Text(
          "สแกนชำระด้วย PromptPay",
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // 🔹 สีพื้นหลัง
                      borderRadius: BorderRadius.circular(12), // 🔹 มุมโค้ง
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ThaiQRWidget(
                      showHeader: false,
                      mobileOrId: "0876947022",
                      amount: _parsePrice(opt.price).toString(),
                    ),
                  ),
                ),

                SizedBox(height: 8),
                Text(
                  "ยอดชำระ: ${opt.price}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // 🔹 บรรทัดแรก: ปุ่มสลิปกับ QR
          if (selectedPayment == 0 || selectedPayment == 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.upload, color: Colors.white),
                  label: const Text(
                    "อัปโหลดสลิป",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: _saveQrToGallery,
                  label: const Text(
                    "QR code",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

          // 🔹 บรรทัดที่สอง: ปุ่ม “ปิด” กับ “ยืนยัน” อยู่ใน Row เดียวกัน
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "ปิด",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home2Screen()));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "ยืนยัน",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return StepProgress(
      totalSteps: 3,
      stepNodeSize: 18,
      controller: stepProgressController,
      nodeTitles: const ['เลือกราคา', 'ตรวจสอบข้อมูล', 'ชำระเงิน'],
      padding: const EdgeInsets.all(18),
      theme: StepProgressThemeData(
        activeForegroundColor: myColor, // ใช้ตัวแปรที่แก้ไขแล้ว
        shape: StepNodeShape.diamond,
        stepLineSpacing: 18,
        stepLineStyle: StepLineStyle(borderRadius: Radius.circular(4)),
        nodeLabelStyle: const StepLabelStyle(
          margin: EdgeInsets.only(bottom: 6),
          titleStyle: TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis),
        ),
        stepNodeStyle: const StepNodeStyle(
          activeIcon: null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceStep() {
    return Column(
      children: [
        const Text(
          'เลือกราคา',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selectedValue == option.value;
              return Card(
                color: isSelected ? Colors.grey[800] : Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: RadioListTile<int>(
                  activeColor: myColor,
                  value: option.value,
                  groupValue: selectedValue,
                  onChanged: (val) {
                    setState(() {
                      selectedValue = val!;
                    });
                  },
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        option.price,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: option.tag != null
                      ? Text(
                          option.tag!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final opt = selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'ตรวจสอบข้อมูล',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white70),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "สรุปรายการ",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rowItem("แพ็กเกจ", opt?.label ?? "-"),
                  _rowItem("ราคา", opt?.price ?? "-"),
                  _rowItem("ผู้ใช้งาน", userName ?? userId ?? "-"),
                  const Divider(),
                  const SizedBox(height: 4),
                  const Text("ข้อมูลเพิ่มเติม"),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "โค้ดส่วนลด (ถ้ามี)",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    onChanged: (v) => referral = v,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final opt = selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ชำระเงิน',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white70),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "สรุปยอดชำระ",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _rowItem("แพ็กเกจ", opt?.label ?? "-"),
                  _rowItem("ราคา", opt?.price ?? "-"),
                  if (referral != null && referral!.isNotEmpty)
                    _rowItem("รหัสอ้างอิง", referral!),
                  const Divider(height: 24),
                  const Text(
                    "เลือกวิธีชำระเงิน",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  // ================= วิธีชำระเงิน =================
                  Card(
                    color: Colors.black,
                    child: RadioListTile<int>(
                      activeColor: myColor,
                      value: 0,
                      groupValue: selectedPayment,
                      onChanged: (v) => setState(() => selectedPayment = v!),
                      title: const Text(
                        "PromptPay",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "สแกน QR พร้อมเพย์",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  Card(
                    color: Colors.black,
                    child: RadioListTile<int>(
                      activeColor: myColor,
                      value: 1,
                      groupValue: selectedPayment,
                      onChanged: (v) => setState(() => selectedPayment = v!),
                      title: const Text(
                        "บัตรเครดิต/เดบิต",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "Visa / MasterCard",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  Card(
                    color: Colors.black,
                    child: RadioListTile<int>(
                      activeColor: myColor,
                      value: 2,
                      groupValue: selectedPayment,
                      onChanged: (v) => setState(() => selectedPayment = v!),
                      title: const Text(
                        "โอนเงินผ่านธนาคาร",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "อัปโหลดสลิปหลังโอน",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ================= เงื่อนไขเพิ่มเติม =================
                  if (selectedPayment == 1)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ข้อมูลบัตรเครดิต",
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "หมายเลขบัตร",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "MM/YY",
                                  labelStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "CVV",
                                  labelStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "ชื่อบนบัตร",
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentStep > 0;
    final isLastStep = currentStep == 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const Navbar2(),
      drawer: ExampleSidebarX(controller: _controller),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepHeader(),
              const SizedBox(height: 16),

              // เนื้อหาตามขั้น
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Builder(
                    key: ValueKey(currentStep),
                    builder: (context) {
                      switch (currentStep) {
                        case 0:
                          return _buildPriceStep();
                        case 1:
                          return _buildReviewStep();
                        case 2:
                          return _buildPaymentStep();
                        default:
                          return _buildPriceStep();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ปุ่มนำทาง
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canGoBack
                          ? myColor
                          : Colors.grey, // ใช้ตัวแปรที่แก้ไขแล้ว
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      minimumSize: const Size(60, 50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: canGoBack ? goPrevious : null,
                    child: const Text(
                      'กลับ',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isLastStep) // เพิ่มเงื่อนไขแสดงปุ่ม
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size(60, 50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: goNext,
                      child: const Text(
                        'ต่อไป',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (isLastStep)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size(60, 50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: payNow,
                      icon: const Icon(Icons.payments, color: Colors.white),
                      label: const Text(
                        'ชำระเงิน',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
