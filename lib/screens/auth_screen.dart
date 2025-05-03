import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _verificationId;
  bool _awaitingSMS = false;

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (RegExp(r'^\d{10,}$').hasMatch(identifier)) {
        // 1️⃣ Handle cellphone login
        setState(() => _awaitingSMS = true);

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: '+27${identifier.substring(identifier.length - 9)}',
          verificationCompleted: (credential) async {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (context.mounted) Navigator.pop(context);
          },
          verificationFailed: (e) {
            setState(() {
              _awaitingSMS = false;
              _errorMessage = e.message;
            });
          },
          codeSent: (verificationId, _) {
            setState(() {
              _verificationId = verificationId;
              _awaitingSMS = true;
            });
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      } else {
        // 2️⃣ Handle email/username login
        String emailToUse = identifier;

        if (!identifier.contains('@')) {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('username_or_cell', isEqualTo: identifier)
              .get();

          if (query.docs.isEmpty) {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found with that cellphone number.',
            );
          }

          emailToUse = query.docs.first['email'];
        }

        if (_isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailToUse,
            password: password,
          );
        } else {
          final userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: emailToUse,
                password: password,
              );

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'email': emailToUse,
                'username_or_cell': identifier,
                'role': emailToUse == 'admin@gmail.com' ? 'admin' : 'user',
              });
        }

        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _submitSMSCode() async {
    try {
      if (_verificationId == null || _smsCodeController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Enter SMS code');
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _resetPassword() async {
    final email = _identifierController.text.trim();

    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _errorMessage = 'Password reset email sent.';
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = RegExp(r'^\d{10,}$').hasMatch(_identifierController.text.trim());

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextFormField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Email / Cellphone',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Enter an identifier' : null,
              ),
              if (!isPhone && !_awaitingSMS) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password';
                    } else if (value.length < 6) {
                      return 'Min 6 characters';
                    }
                    return null;
                  },
                ),
              ],
              if (_awaitingSMS) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _smsCodeController,
                  decoration: const InputDecoration(
                    labelText: 'SMS Code',
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitSMSCode,
                  child: const Text('Verify Code'),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isLogin ? 'Login' : 'Register'),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin
                    ? 'Create an account'
                    : 'Already have an account?'),
              ),
              if (_isLogin && !isPhone && !_awaitingSMS)
                TextButton(
                  onPressed: _resetPassword,
                  child: const Text('Forgot Password?'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
