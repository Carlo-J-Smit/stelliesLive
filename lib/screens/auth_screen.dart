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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _awaitingSMS = false;
  bool _isPhone = false;

  String? _errorMessage;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(() {
      final text = _identifierController.text.trim();
      final isNowPhone = RegExp(r'^0\d{9}$').hasMatch(text);
      if (isNowPhone != _isPhone) {
        setState(() {
          _isPhone = isNowPhone;
        });
      }
    });
  }

  Future<void> _submit() async {
  setState(() => _errorMessage = null);
  if (!_formKey.currentState!.validate()) return;

  final identifier = _identifierController.text.trim();
  final password = _passwordController.text.trim();

  try {
    if (_isPhone) {
      setState(() => _awaitingSMS = true);

      final phoneDigits = identifier.replaceFirst('0', '');
      final formattedPhone = '+27$phoneDigits';

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
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

        final uid = userCredential.user!.uid;
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

// 1. Create/merge the main user document
        await userRef.set({
          'email': emailToUse,
          'username_or_cell': identifier,
          'role': emailToUse == 'admin@gmail.com' ? 'admin' : 'user',
          'business_name' : '',
          'business_ids' : FieldValue.arrayUnion([]),
        }, SetOptions(merge: true));

// 2. Create default notification preferences
        await userRef
            .collection('notificationPreferences')
            .doc('settings')
            .set({
          'category_default': true,
          'category_busy': true,
          'quiet_hours_enabled': false,
          'quiet_start': "22:00",
          'quiet_end': "07:00",
        }, SetOptions(merge: true));

      }

      if (context.mounted) Navigator.pop(context);
    }
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No user found with those credentials.';
        break;
      case 'wrong-password':
        _errorMessage = 'Incorrect password.';
        break;
      case 'invalid-email':
        _errorMessage = 'Email address is badly formatted.';
        break;
      case 'user-disabled':
        _errorMessage = 'This account has been disabled.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'This email is already registered.';
        break;
      case 'weak-password':
        _errorMessage = 'The password is too weak.';
        break;
      default:
        _errorMessage = 'Authentication failed. (Incorrect password for this account)';
    }
    setState(() {});
  } catch (e) {
    setState(() => _errorMessage = 'Unexpected error: ${e.toString()}');
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
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: InputDecoration(
                  labelText: 'Email', //'Email / cellphone number'
                  helperText:
                      _isPhone
                          ? 'Format: 0XXXXXXXXX (e.g. 0831234567)'
                          : 'Use a valid email eg. name.surname@gmail.com', //'Use a valid email or cellphone number'
                ),
                keyboardType: TextInputType.emailAddress,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter an identifier'
                            : null,
              ),
              if (!_isPhone && !_awaitingSMS) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
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
                if (!_isLogin) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      } else if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ],
              if (_awaitingSMS) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _smsCodeController,
                  decoration: const InputDecoration(labelText: 'SMS Code'),
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
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isLogin ? 'Create an account' : 'Already have an account?',
                ),
              ),
              if (_isLogin && !_isPhone && !_awaitingSMS)
                const SizedBox(height: 10),
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

  Widget _buildPasswordCriteria(String password) {
    bool hasMinLength = password.length >= 6;
    bool hasNumber = password.contains(RegExp(r'\d'));
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCriteriaItem('At least 6 characters', hasMinLength),
        _buildCriteriaItem('Contains a number', hasNumber),
        _buildCriteriaItem('Contains uppercase letter', hasUpper),
        _buildCriteriaItem('Contains lowercase letter', hasLower),
      ],
    );
  }

  Widget _buildCriteriaItem(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check : Icons.close,
          color: met ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: met ? Colors.green : Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
