import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _showBlueskyLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    // Wait for auth service to finish loading
    while (auth.isLoading && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (auth.isLoggedIn && mounted) {
      Navigator.pushReplacementNamed(context, '/characters');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final (success, message) = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pushReplacementNamed(context, '/characters');
      } else {
        setState(() => _errorMessage = message);
      }
    }
  }

  Future<void> _loginWithBluesky() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthService>();
    final (success, message) = await auth.loginWithBluesky(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pushReplacementNamed(context, '/characters');
      } else {
        setState(() => _errorMessage = message);
      }
    }
  }

  void _toggleLoginMode() {
    setState(() {
      _showBlueskyLogin = !_showBlueskyLogin;
      _errorMessage = null;
      _usernameController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo
              _buildLogo(),
              const SizedBox(height: 48),
              // Form
              _buildForm(),
              const SizedBox(height: 24),
              // Register link
              _buildRegisterLink(),
              const SizedBox(height: 48),
              // Features
              _buildFeatures(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.smart_toy,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'SynthChat',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your AI Character Companion',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Login mode toggle
          _buildLoginModeToggle(),
          const SizedBox(height: 24),
          // Username/Handle field
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: _showBlueskyLogin 
                  ? 'Bluesky Handle (e.g., user.bsky.social)'
                  : 'Username or Email',
              prefixIcon: Icon(_showBlueskyLogin 
                  ? Icons.alternate_email 
                  : Icons.person_outline),
              hintText: _showBlueskyLogin 
                  ? 'yourname.bsky.social' 
                  : null,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _showBlueskyLogin 
                    ? 'Please enter your Bluesky handle'
                    : 'Please enter your username or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Password field
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: _showBlueskyLogin ? 'App Password' : 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              helperText: _showBlueskyLogin 
                  ? 'Use an App Password from Settings → App Passwords'
                  : null,
              helperMaxLines: 2,
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _showBlueskyLogin ? _loginWithBluesky() : _login(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _showBlueskyLogin 
                    ? 'Please enter your app password'
                    : 'Please enter your password';
              }
              return null;
            },
          ),
          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Login button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading 
                  ? null 
                  : (_showBlueskyLogin ? _loginWithBluesky : _login),
              style: _showBlueskyLogin 
                  ? ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0085FF), // Bluesky blue
                    )
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_showBlueskyLogin ? Icons.cloud : Icons.login),
                        const SizedBox(width: 8),
                        Text(_showBlueskyLogin 
                            ? 'Sign In with Bluesky' 
                            : 'Sign In'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              'Local Account',
              Icons.person,
              !_showBlueskyLogin,
              () => setState(() {
                _showBlueskyLogin = false;
                _errorMessage = null;
              }),
            ),
          ),
          Expanded(
            child: _buildModeButton(
              'Bluesky',
              Icons.cloud,
              _showBlueskyLogin,
              () => setState(() {
                _showBlueskyLogin = true;
                _errorMessage = null;
              }),
              color: const Color(0xFF0085FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    String label, 
    IconData icon, 
    bool isSelected, 
    VoidCallback onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (color ?? AppColors.primary).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected 
                  ? (color ?? AppColors.primary) 
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? (color ?? AppColors.primary) 
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('Create one'),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    return Column(
      children: [
        _buildFeatureItem(
          Icons.groups,
          'Multiple Characters',
          'Create unique AI personalities',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.cloud_sync,
          'Cloud Memory',
          'Conversations saved securely',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.psychology,
          'Evolving Personalities',
          'Characters remember and grow',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          Icons.language,
          'Bluesky Integration',
          'Federated login via AT Protocol',
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
