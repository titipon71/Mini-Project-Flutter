import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_app/screens/home2_screen.dart';
import 'package:my_app/screens/sign_up_screen.dart';
import 'package:simple_icons/simple_icons.dart';
// import 'package:my_app/screens/onboarding_screen.dart';
import 'welcome_screen.dart'; // ใช้ AbstractBackground + shared atoms

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  // bool _remember = true;
  // bool _loading = false; // เผื่อไว้ถ้าจะกันกดซ้ำ


  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // --- Web ใช้ Popup ---
        final googleProvider = GoogleAuthProvider();
        // หากต้องการขอ scope เพิ่มเติม ให้เพิ่มแบบนี้:
        // googleProvider.addScope('https://www.googleapis.com/auth/userinfo.profile');
        final userCredential = await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const Home2Screen()),
          );
        }
        return;
      }

      // --- Android/iOS ใช้ google_sign_in ---
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // ถ้าต้องการจำกัด scope เพิ่มเติม:
        // scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // ผู้ใช้กดยกเลิก
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Home2Screen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'ไม่สามารถเข้าสู่ระบบด้วย Google ได้';
      // เคสพบบ่อย ๆ
      if (e.code == 'account-exists-with-different-credential') {
        msg = 'อีเมลนี้ผูกกับวิธีเข้าสู่ระบบอื่นอยู่ (เช่น Email/Password)';
      } else if (e.code == 'popup-closed-by-user') {
        msg = 'ปิดหน้าต่างก่อนดำเนินการเสร็จ';
      } else if (e.code == 'web-context-cancelled') {
        msg = 'การยืนยันตนถูกยกเลิก';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด')));
    }
  }

  Future<void> signInWithGithub() async {
    try {
      if (kIsWeb) {
        // --- Web ใช้ Popup ---
        final githubProvider = GithubAuthProvider();
        // หากต้องการขอ scope เพิ่มเติม ให้เพิ่มแบบนี้:
        // githubProvider.addScope('repo');
        final userCredential = await FirebaseAuth.instance.signInWithPopup(
          githubProvider,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const Home2Screen()),
          );
        }
        return;
      }

      // --- Android/iOS ยังไม่รองรับ GitHub Sign-In ---
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Sign-In รองรับเฉพาะบนเว็บเท่านั้น')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'ไม่สามารถเข้าสู่ระบบด้วย GitHub ได้';
      // เคสพบบ่อย ๆ
      if (e.code == 'account-exists-with-different-credential') {
        msg = 'อีเมลนี้ผูกกับวิธีเข้าสู่ระบบอื่นอยู่ (เช่น Email/Password)';
      } else if (e.code == 'popup-closed-by-user') {
        msg = 'ปิดหน้าต่างก่อนดำเนินการเสร็จ';
      } else if (e.code == 'web-context-cancelled') {
        msg = 'การยืนยันตนถูกยกเลิก';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด')));
    }
  }

  Future<void> loginWithEmail() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      // เข้าสู่ระบบสำเร็จ ไปหน้า Onboarding
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Home2Screen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'เข้าสู่ระบบไม่สำเร็จ';
      if (e.code == 'user-not-found') {
        msg = 'ไม่พบผู้ใช้นี้';
      } else if (e.code == 'wrong-password') {
        msg = 'รหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'invalid-email') {
        msg = 'อีเมลไม่ถูกต้อง';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด')));
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form != null && form.validate()) {
      loginWithEmail();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
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
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
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
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                AppTextField(
                                  label: 'Email',
                                  hint: 'name@example.com',
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
                                  // onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(), // ถ้า AppTextField รองรับ
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Password',
                                  hint: 'Enter Password',
                                  controller: _password,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) {
                                      return 'Please enter password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Checkbox(
                                    //   value: _remember,
                                    //   onChanged: (v) =>
                                    //       setState(() => _remember = v ?? false),
                                    // ),
                                    // const Text('Remember me'),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Forgot password?'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 50,
                                  child: FilledButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFF6B606),
                                    ),
                                    onPressed: _submit,
                                    child: const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const DividerWithText('Sign in with'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: signInWithGoogle,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.g_mobiledata, size: 30, fill: 1, textDirection: TextDirection.rtl), // ใส่ไอคอนของคุณ
                                        const Text('Continue with Google'),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: signInWithGithub,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(SimpleIcons.github, size: 20, textDirection: TextDirection.ltr), // ใส่ไอคอนของคุณ
                                        const Text('  Continue with Github'),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Don't have an account? "),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SignUpScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          color: Color(0xFFF6B606),
                                          decoration: TextDecoration.underline,
                                          decorationColor: Color(0xFFF6B606),
                                          decorationStyle:
                                              TextDecorationStyle.solid,
                                        ),
                                      ),
                                    ),
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
      ),
    );
  }
}
