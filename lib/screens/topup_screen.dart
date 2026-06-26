import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Twebtoon/services/api_service.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:Twebtoon/assets/widgets/app_sidebar.dart';
import 'package:Twebtoon/screens/home2_screen.dart';
import 'package:Twebtoon/screens/navbar2_screen.dart';
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

// SlipOK proxy ย้ายไปอยู่ที่ FastAPI backend แล้ว
String get _SLIPOK_URL => '${ApiService.baseUrl}/api/v1/payments/slipok/verify';


class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  StreamSubscription? _topupSub;
  final GlobalKey _qrKey = GlobalKey();
  final stepProgressController = StepProgressController(
    totalSteps: 3,
    initialStep: 0,
  );
  bool isSavingTopup = false;
  final myColor = const Color(0xFFF6B606); // แก้ไขการประกาศตัวแปร
  double _parsePrice(String priceText) {
    return double.tryParse(priceText.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  Stream<bool> _vipStream(String uid) async* {
    while (true) {
      try {
        final response = await ApiService.get('/api/v1/me/roles');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          yield json['vip'] == true;
        } else {
          yield false;
        }
      } catch (_) {
        yield false;
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }


  bool isUploadingSlip = false;
  double uploadProgress = 0.0; // 0.0 - 1.0
  bool uploadSuccess = false;
  String? slipFileName;
  Uint8List?
  slipBytes; // เผื่ออยากเก็บตัวไฟล์ไว้ใช้งานต่อ (เช่น ส่งขึ้น backend)
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

  Future<void> _approveTopupAndMarkVip({
    required String topupId,
    required String uid,
    required int days,
    Map<String, dynamic>? slipokPayload,
  }) async {
    await ApiService.patch('/api/v1/admin/topups/$topupId', {
      'status': 'paid',
      if (slipokPayload != null) 'slipokPayload': slipokPayload,
    });
  }

  Future<bool> _verifyWithSlipOK({
    required String topupId,
    required double amountExpected,
    required String uid,
    required int packageDays,
    String? slipUrl,
  }) async {
    try {
      final body = {
        if (slipUrl != null) 'url': slipUrl,
        'amount': amountExpected,
        'refCode': topupId,
      };

      final res = await http
    .post(
      Uri.parse(_SLIPOK_URL),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    )
    .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
  final err = res.body.isNotEmpty ? res.body : 'no body';
  _showSnack('SlipOK error: HTTP ${res.statusCode} • $err');
  debugPrint('[SlipOK] ${res.statusCode} ${res.body}');
  return false;
}

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (jsonMap['data'] ?? {}) as Map<String, dynamic>;
      final bool success = data['success'] == true;

      final num? amountFromSlip = (data['amount'] is num)
          ? data['amount'] as num
          : null;
      bool amountOk = true;
      if (amountFromSlip != null) {
        amountOk =
            (amountFromSlip.toDouble() - amountExpected).abs() <
            0.5; // เผื่อ 0.5 บาท
      }

      if (success && amountOk) {
        await _approveTopupAndMarkVip(
          topupId: topupId,
          uid: uid,
          days: packageDays,
          slipokPayload: jsonMap,
        );
        _showSnack('✅ ตรวจสลิปผ่าน • อัปเดต VIP แล้ว');
        return true; // ← บอกว่าผ่าน
      } else {
        await ApiService.patch('/api/v1/admin/topups/$topupId', {
          'status': 'pending',
          'failReason': success ? 'amount_mismatch' : 'slip_verify_failed',
        });
        _showSnack('❌ ตรวจสลิปไม่ผ่าน');
        return false;
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
      print(e);
      return false;
    }
  }

  Future<String?> _uploadSlipToStorage(String topupId) async {
    if (slipBytes == null || slipBytes!.isEmpty) return null;

    final fileName =
        slipFileName ?? 'slip_${DateTime.now().millisecondsSinceEpoch}.png';

    final response = await ApiService.uploadBytes(
      bytes: slipBytes!,
      filename: fileName,
      purpose: UploadPurpose.topupSlip,
      topupId: topupId,
    );

    return ApiService.parseUploadUrl(response);
  }

  Future<void> _requestManualVerify({
    required String topupId,
    required String refCode,
    required String slipUrl,
  }) async {
    final res = await ApiService.post(
      '/api/v1/payments/topups/$topupId/manual-verify',
      {'slipUrl': slipUrl},
    );
    if (res.statusCode != 200) {
      _showSnack('ตรวจสลิปไม่สำเร็จ (${res.statusCode})');
    }
  }

  Future<String> _saveTopup({
    required String topupId,
    required String userId,
    required String? userName,
    required SubscriptionOption option,
    required String paymentMethod,
    required String refCode,
    String? referralCode,
    String? slipUrl,
  }) async {
    final amount = _parsePrice(option.price);
    final expiresAt = DateTime.now().add(const Duration(hours: 48));

    await ApiService.post('/api/v1/topups', {
      'topupId': topupId,
      'userName': userName ?? userId,
      'packageLabel': option.label,
      'packageValue': option.value,
      'priceText': option.price,
      'amount': amount,
      'amountExpected': amount,
      'paymentMethod': paymentMethod,
      'refCode': refCode,
      'referral': (referralCode?.isNotEmpty ?? false) ? referralCode : null,
      'slipUrl': slipUrl,
      'platform': kIsWeb ? 'web' : 'mobile',
      'qrAmount': amount,
      'qrTarget': '0876947022',
      'roleTarget': 'vip',
      'durationDays': _mapPackageToDays(option.value),
      'expiresAt': expiresAt.toIso8601String(),
    });
    return topupId;
  }

  // helper ง่าย ๆ
  int _mapPackageToDays(int value) {
    switch (value) {
      case 0:
        return 2;
      case 1:
        return 7;
      case 2:
        return 15;
      case 3:
        return 30;
      case 4:
        return 45;
      case 5:
        return 60;
      case 6:
        return 365;
      default:
        return 0;
    }
  }

  void _listenTopup(String topupId) {
    _topupSub?.cancel();
    // poll สถานะทุก 5 วินาที
    _topupSub = Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => ApiService.get('/api/v1/topups/$topupId'))
        .listen((response) async {
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 'approved' || data['status'] == 'paid') {
        _showSnack('✅ ยืนยันการชำระแล้ว! สิทธิ์ถูกอัปเดต');
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  Future<void> _pickAndUploadSlip({
    void Function(void Function())? setStateDialog,
  }) async {
    // ✅ ฟังก์ชันช่วยอัปเดตทั้ง Dialog และ State หลักพร้อมกัน
    void refresh(VoidCallback fn) {
      if (mounted) setState(fn);
      if (setStateDialog != null) setStateDialog(fn);
    }

    refresh(() {
      uploadSuccess = false;
      isUploadingSlip = true;
      uploadProgress = 0.0;
    });

    try {
      if (kIsWeb) {
        final input = html.FileUploadInputElement()
          ..accept = 'image/*'
          ..multiple = false
          ..click();

        await input.onChange.first;
        if (input.files == null || input.files!.isEmpty) {
          refresh(() => isUploadingSlip = false);
          return;
        }

        final file = input.files!.first;
        final reader = html.FileReader();
        final completer = Completer<void>();
        reader.onLoadEnd.listen((_) => completer.complete());
        reader.readAsArrayBuffer(file);
        await completer.future;

        // ✅ รองรับได้ทั้ง ByteBuffer และ NativeUint8List
        final result = reader.result;
        late Uint8List data;
        if (result is ByteBuffer) {
          data = result.asUint8List();
        } else if (result is Uint8List) {
          data = result;
        } else if (result is String) {
          // เผื่อกรณี base64 string
          final comma = result.indexOf(',');
          final b64 = comma != -1 ? result.substring(comma + 1) : result;
          data = base64Decode(b64);
        } else {
          throw StateError(
            'Unsupported FileReader.result type: ${result.runtimeType}',
          );
        }

        refresh(() {
          slipFileName = file.name;
          slipBytes = data;
        });

        // จำลอง progress
        for (int i = 1; i <= 20; i++) {
          await Future.delayed(const Duration(milliseconds: 80));
          refresh(() => uploadProgress = i / 20);
        }

        refresh(() {
          isUploadingSlip = false;
          uploadSuccess = true;
        });

        _showSnack('✅ อัปโหลดสลิปสำเร็จ');
      } else {
        _showSnack(
          'โปรดติดตั้ง file_picker หรือ image_picker เพื่อเลือกสลิปบนมือถือ',
        );
        refresh(() => isUploadingSlip = false);
      }
    } catch (e) {
      refresh(() {
        isUploadingSlip = false;
        uploadSuccess = false;
      });
      _showSnack('อัปโหลดไม่สำเร็จ: $e');
    }
  }

  Future<void> _saveQrToGallery() async {
    try {
      final ctx = _qrKey.currentContext;
      if (ctx == null) {
        _showSnack('ยังเตรียมภาพไม่เสร็จ ลองใหม่อีกครั้ง');
        return;
      }
      // 🔹 1. แปลง Widget เป็น PNG bytes
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
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

        final ok =
            (result is Map) &&
            (result['isSuccess'] == true || result['filePath'] != null);
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

@override
  void dispose() {
    stepProgressController.dispose();
    // ยกเลิกสตรีมถ้ามี (ดูหมายเหตุด้านล่าง)
    _topupSub?.cancel();
    super.dispose();
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

  void _showPromptPayQR(BuildContext context) {
    final opt = selectedOption;
    if (opt == null) {
      _showSnack("กรุณาเลือกแพ็กเกจ");
      return;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return WillPopScope(
            onWillPop: () async => !isSavingTopup,
            child: AlertDialog(
              actionsAlignment: MainAxisAlignment.center, // จัดกึ่งกลาง
              actionsOverflowButtonSpacing: 12, // ระยะห่างเมื่อพับบรรทัด
              actionsOverflowDirection:
                  VerticalDirection.down, // ถ้าล้น ให้ขึ้นบรรทัดใหม่ลงล่าง
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),

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
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // 🔹 มุมโค้ง
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
                      // แสดงชื่อไฟล์ (ถ้ามี)
                      if (slipFileName != null && slipFileName!.isNotEmpty)
                        Text(
                          "ไฟล์: $slipFileName",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Progress bar ระหว่างอัปโหลด
                      if (isUploadingSlip) ...[
                        LinearProgressIndicator(
                          color: Colors.greenAccent,
                          value: uploadProgress == 0.0 ? null : uploadProgress,
                          backgroundColor: Colors.white10,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadProgress == 0.0
                              ? "กำลังอัปโหลด..."
                              : "กำลังอัปโหลด ${(uploadProgress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      // Alert-success เมื่ออัปโหลดเสร็จ
                      if (uploadSuccess) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Color(0xFF1B5E20), // เขียวเข้ม
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.greenAccent.shade400,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "อัปโหลดสลิปสำเร็จ",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              actions: [
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
                        onPressed: () =>
                            _pickAndUploadSlip(setStateDialog: setStateDialog),
                        icon: const Icon(Icons.upload, color: Colors.white),
                        label: const Text(
                          "อัปโหลดสลิป",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _saveQrToGallery,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          "QR code",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                // 🔹 แถวปุ่มหลัก: ยกเลิก(ซ้าย) + ยืนยัน(ขวา)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: isSavingTopup
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          "ปิด",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: isSavingTopup
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, color: Colors.white),
                        label: const Text('ยืนยัน'),
                        onPressed: isSavingTopup
                            ? null
                            : () async {
                                final opt = selectedOption;
                                if (opt == null) {
                                  _showSnack('กรุณาเลือกแพ็กเกจ');
                                  return;
                                }

                                // helper อัปเดตทั้ง dialog และหน้าหลัก
                                void refresh(VoidCallback fn) {
                                  if (mounted) setState(fn);
                                  setStateDialog(fn);
                                }

                                try {
                                  refresh(() => isSavingTopup = true);

                                  // 1) เตรียม topupId
                                  // สร้าง UUID สำหรับ topupId
                                  final topupId = DateTime.now().millisecondsSinceEpoch.toString();

                                  // 2) อัปโหลดสลิป (ถ้ามี)
                                  String? slipUrl;
                                  if (slipBytes != null &&
                                      slipBytes!.isNotEmpty) {
                                    slipUrl = await _uploadSlipToStorage(
                                      topupId,
                                    );
                                  } else {
                                    _showSnack('กรุณาอัปโหลดสลิปก่อนยืนยัน');
                                    return;
                                  }

                                  // 3) gen refCode
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) {
                                    _showSnack('ไม่พบผู้ใช้');
                                    return;
                                  }
                                  final refCode =
                                      'TOPUP-${DateTime.now().millisecondsSinceEpoch}-$uid';

                                  // 4) บันทึก topup ผ่าน API
                                  await _saveTopup(
                                    topupId: topupId,
                                    userId: uid,
                                    userName: userName,
                                    option: opt,
                                    paymentMethod: (selectedPayment == 0)
                                        ? 'promptpay'
                                        : (selectedPayment == 1)
                                        ? 'card'
                                        : 'bank_transfer',
                                    referralCode: referral,
                                    slipUrl: slipUrl,
                                    refCode: refCode,
                                  );

                                  // 5) ยิง SlipOK → ถ้าผ่านจะ approved + set VIP ให้เลย (ไม่แตะ index.js)
                                  final amount = _parsePrice(opt.price);
                                  final days = _mapPackageToDays(opt.value);
                                  final ok = await _verifyWithSlipOK(
                                    topupId: topupId,
                                    amountExpected: amount,
                                    uid: uid,
                                    packageDays: days,
                                    slipUrl: slipUrl,
                                  );
                                  if (ok) {
                                    Navigator.of(
                                      dialogCtx,
                                    ).pop(); // ← ปิดเฉพาะ Dialog
                                    Navigator.pushReplacement(context, MaterialPageRoute(
                                      builder: (_) => const Home2Screen(),
                                    ));
                                  }

                                  // (ออปชัน) ถ้าจะฟัง topup ก็ได้ แต่ไม่จำเป็นแล้วเพราะเราตัดสินผลเอง
                                  // _listenTopup(topupId);
                                } catch (e) {
                                  _showSnack('บันทึก/ตรวจสลิปไม่สำเร็จ: $e');
                                } finally {
                                  refresh(() => isSavingTopup = false);
                                }
                              },
                      ),
                    ], // before end FilledButton.icon
                  ),
                ),
              ],
            ),
          );
        },
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
      final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const Navbar2(),
      drawer: const Drawer(child: AppSidebar()),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepHeader(),


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
