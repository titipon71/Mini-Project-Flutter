import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/helpers/user_role_extension.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isVip = false;
  bool _isAdmin = false;
  User? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() {
      _currentUser = user;
      _displayNameController.text = user.displayName ?? '';
    });
    
    // โหลดสถานะ VIP และ Admin
    try {
      final isVip = await user.isVIP(refresh: true);
      final isAdmin = await user.isAdmin(refresh: true);
      
      if (mounted) {
        setState(() {
          _isVip = isVip;
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('Error loading user roles: $e');
    }
  }

  Future<void> _updateDisplayName() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // อัปเดต Display Name ใน Firebase Auth
      await user.updateDisplayName(_displayNameController.text.trim());
      
      // อัปเดตใน Firestore (ถ้ามีเอกสาร users)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'displayName': _displayNameController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // ถ้าไม่มีเอกสาร users ก็ไม่เป็นไร
        print('Firestore update skipped: $e');
      }
      
      // รีเฟรช user profile
      await user.reload();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // อัปเดต _currentUser
        setState(() {
          _currentUser = FirebaseAuth.instance.currentUser;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update display name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send password reset email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // ลบข้อมูลใน Firestore ก่อน (ถ้ามี)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        print('Firestore deletion skipped: $e');
      }
      
      // ลบบัญชี Firebase Auth
      await user.delete();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: Text('Please sign in to access settings'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Settings'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Profile Information',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Email (Read-only)
                            TextFormField(
                              initialValue: _currentUser!.email ?? 'No email',
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            
                            // Display Name (Editable)
                            TextFormField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                                hintText: 'Enter your display name',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Display name cannot be empty';
                                }
                                if (value.trim().length < 2) {
                                  return 'Display name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Update Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _updateDisplayName,
                                icon: const Icon(Icons.save),
                                label: const Text('Update Display Name'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // // Account Status Section
                    // Card(
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Row(
                    //           children: [
                    //             const Icon(Icons.verified_user, size: 24),
                    //             const SizedBox(width: 8),
                    //             Text(
                    //               'Account Status',
                    //               style: Theme.of(context).textTheme.titleLarge,
                    //             ),
                    //           ],
                    //         ),
                    //         const SizedBox(height: 16),
                            
                    //         // VIP Status
                    //         Row(
                    //           children: [
                    //             Icon(
                    //               _isVip ? Icons.workspace_premium : Icons.person,
                    //               color: _isVip ? Colors.amber : Colors.grey,
                    //             ),
                    //             const SizedBox(width: 8),
                    //             Text(
                    //               _isVip ? 'VIP Member' : 'Regular Member',
                    //               style: TextStyle(
                    //                 color: _isVip ? Colors.amber : Colors.grey,
                    //                 fontWeight: FontWeight.bold,
                    //               ),
                    //             ),
                    //           ],
                    //         ),
                            
                    //         // Admin Status
                    //         if (_isAdmin) ...[
                    //           const SizedBox(height: 8),
                    //           Row(
                    //             children: [
                    //               Icon(
                    //                 Icons.admin_panel_settings,
                    //                 color: Colors.red[600],
                    //               ),
                    //               const SizedBox(width: 8),
                    //               Text(
                    //                 'Administrator',
                    //                 style: TextStyle(
                    //                   color: Colors.red[600],
                    //                   fontWeight: FontWeight.bold,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),
                    //         ],
                            
                    //         const SizedBox(height: 8),
                    //         Text(
                    //           'User ID: ${_currentUser!.uid}',
                    //           style: Theme.of(context).textTheme.bodySmall,
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    
                    // const SizedBox(height: 16),
                    
                    // // Security Section
                    // Card(
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Row(
                    //           children: [
                    //             const Icon(Icons.security, size: 24),
                    //             const SizedBox(width: 8),
                    //             Text(
                    //               'Security',
                    //               style: Theme.of(context).textTheme.titleLarge,
                    //             ),
                    //           ],
                    //         ),
                    //         const SizedBox(height: 16),
                            
                    //         // Change Password Button
                    //         SizedBox(
                    //           width: double.infinity,
                    //           child: ElevatedButton.icon(
                    //             onPressed: _changePassword,
                    //             icon: const Icon(Icons.lock_reset),
                    //             label: const Text('Reset Password'),
                    //             style: ElevatedButton.styleFrom(
                    //               backgroundColor: Colors.orange,
                    //               foregroundColor: Colors.white,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    
                    // const SizedBox(height: 16),
                    
                    // // Danger Zone
                    // Card(
                    //   color: Colors.red[50],
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Row(
                    //           children: [
                    //             Icon(Icons.warning, size: 24, color: Colors.red[700]),
                    //             const SizedBox(width: 8),
                    //             Text(
                    //               'Danger Zone',
                    //               style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    //                 color: Colors.red[700],
                    //               ),
                    //             ),
                    //           ],
                    //         ),
                    //         const SizedBox(height: 16),
                            
                    //         const Text(
                    //           'Once you delete your account, there is no going back. Please be certain.',
                    //           style: TextStyle(color: Colors.red),
                    //         ),
                    //         const SizedBox(height: 16),
                            
                    //         // Delete Account Button
                    //         SizedBox(
                    //           width: double.infinity,
                    //           child: ElevatedButton.icon(
                    //             onPressed: _deleteAccount,
                    //             icon: const Icon(Icons.delete_forever),
                    //             label: const Text('Delete Account'),
                    //             style: ElevatedButton.styleFrom(
                    //               backgroundColor: Colors.red,
                    //               foregroundColor: Colors.white,
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}