import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'DashBoard.dart' show DashBoard;
import 'signUp.dart';
import 'reset_password.dart';

class SignInPage extends StatefulWidget {
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // State variables to catch and display Firebase API errors inline
  String? _firebaseEmailError;
  String? _firebasePasswordError;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // Clear any previous backend errors before validating again
    setState(() {
      _firebaseEmailError = null;
      _firebasePasswordError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔵 Starting sign in process...');
      print('Email: ${_emailController.text.trim()}');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ Sign in successful: ${userCredential.user!.uid}');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => DashBoard()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      
      setState(() {
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-email':
            _firebaseEmailError = 'No user found with this email or format is invalid.';
            break;
          case 'wrong-password':
            _firebasePasswordError = 'Incorrect password.';
            break;
          case 'user-disabled':
            _firebaseEmailError = 'This account has been disabled.';
            break;
          case 'invalid-credential':
            // Modern Firebase targets this generic error code for security.
            // We apply it inline to the password field or customize as needed.
            _firebasePasswordError = 'Invalid email or password.';
            break;
          default:
            _firebasePasswordError = e.message ?? 'An error occurred during sign in.';
        }
      });

      // Force the form to rebuild and display our freshly set inline error messages
      _formKey.currentState!.validate();

    } catch (e) {
      print('❌ Unexpected error: $e');
      setState(() {
        _firebasePasswordError = 'An unexpected error occurred. Please try again.';
      });
      _formKey.currentState!.validate();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    // Return the backend error if one exists
    return _firebaseEmailError;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    // Return the backend error if one exists
    return _firebasePasswordError;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            /// ⚪ LEFT SIDE — Sign In Form
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 40),
                  child: _buildSignInForm(),
                ),
              ),
            ),

            /// 🎨 RIGHT SIDE — Branding Panel
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF8BBD0), // pink
                      Color(0xFF0D1B2A), // dark navy
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 60),
                    Text(
                      "Welcome back\nto Watad",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "We've missed your study energy! Let's review together again!",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),

          const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 32),

          _buildTextField(
            _emailController,
            "Email Address",
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 20),

          _buildPasswordField(),
          const SizedBox(height: 28),
          _buildSignInButton(),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? "),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                  );
                },
                child: const Text("Sign Up"),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const ResetPasswordPage()),
                );
              },
              child: const Text('Forgot password?'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const UnderlineInputBorder(),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      validator: _validatePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        border: const UnderlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF8BBD0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}