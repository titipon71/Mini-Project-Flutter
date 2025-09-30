import 'package:flutter/material.dart';
import 'package:my_app/screens/onboarding_screen.dart';
import 'welcome_screen.dart'; // ใช้ AbstractBackground + shared atoms
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();

  bool _agree = true;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  String? _agreeError;

  Future<void> registerWithEmail() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      // อัปเดตชื่อผู้ใช้ (display name)
      await credential.user?.updateDisplayName(_name.text.trim());

      // ไปหน้า onboarding
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'สมัครสมาชิกไม่สำเร็จ';
      if (e.code == 'email-already-in-use') {
        msg = 'อีเมลนี้ถูกใช้ไปแล้ว';
      } else if (e.code == 'invalid-email') {
        msg = 'อีเมลไม่ถูกต้อง';
      } else if (e.code == 'weak-password') {
        msg = 'รหัสผ่านอ่อนเกินไป';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Required';
    if (value.length < 6) return 'Min 6 chars';
    return null;
  }

  String? _validatePasswordConfirmation(String? v) {
    final confirm = (v ?? '').trim();
    final pass = _password.text.trim();

    // ใช้กฎเดียวกับ password ก่อน
    final base = _validatePassword(confirm);
    if (base != null) return base;

    // แล้วค่อยเช็คความตรงกัน
    if (confirm != pass) return 'Passwords do not match';
    return null;
  }

  void _submit() {
    // รีเซ็ต error ของ checkbox ก่อน
    setState(() => _agreeError = null);

    final ok = _formKey.currentState!.validate();

    if (!ok || !_agree) {
      if (!_agree) {
        setState(() => _agreeError = 'กรุณายอมรับเงื่อนไขก่อนดำเนินการต่อ');
      }
      return;
    }

    // สมัครสมาชิกจริง
    registerWithEmail();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        child: SafeArea(
          child: Column(
            children: [
              const BackButtonBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Get Started',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 22),
                              AppTextField(
                                label: 'Full Name',
                                hint: 'Enter Full Name',
                                controller: _name,
                                textInputAction: TextInputAction.next,
                                validator: (v) =>
                                    v!.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Email',
                                hint: 'Enter Email',
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) {
                                      return 'Please enter email';
                                    }
                                    final emailOk = RegExp(
                                      r'^[^@]+@[^@]+\.[^@]+$',
                                    ).hasMatch(value);
                                    if (!emailOk) {
                                      return 'Please enter valid email';
                                    }
                                    return null;
                                  },
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Password',
                                hint: 'Enter Password',
                                controller: _password,
                                obscureText: _obscurePwd,
                                textInputAction: TextInputAction.next,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePwd
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePwd = !_obscurePwd),
                                ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                label: 'Password Confirmation',
                                hint: 'Enter Password Again',
                                controller: _passwordConfirmation,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),
                                validator: _validatePasswordConfirmation,
                              ),
                              const SizedBox(height: 8),
                              
                              if (_agreeError != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    _agreeError!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromARGB(255, 0, 66, 234),
                                  ),
                                  onPressed: _submit,
                                  child: const Text('Sign up'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const DividerWithText('Sign up with'),
                              const SizedBox(height: 12),
                              const SocialRow(),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Already have an account? '),
                                  LinkText('Sign in'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
