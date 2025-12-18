import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  bool _isLogin = true;
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (_isScanning) {
      _scannerController ??= MobileScannerController();
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('Сканировать QR код'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isScanning = false;
              });
              _scannerController?.dispose();
              _scannerController = null;
            },
          ),
        ),
        body: MobileScanner(
          controller: _scannerController!,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                // Парсим QR код - извлекаем только код из URL
                String inviteCode = barcode.rawValue!;
                
                // Если это URL типа maymessenger://invite?code=XXXXX
                if (inviteCode.contains('?code=')) {
                  final uri = Uri.parse(inviteCode);
                  inviteCode = uri.queryParameters['code'] ?? inviteCode;
                }
                
                setState(() {
                  _inviteCodeController.text = inviteCode;
                  _isScanning = false;
                });
                _scannerController?.stop();
                break;
              }
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.message,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'May Messenger',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 40),
              
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Номер телефона',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              
              if (!_isLogin) ...[
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Подтвердите пароль',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              if (!_isLogin) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Код приглашения',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isScanning = true;
                        });
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Сканировать QR',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              if (authState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authState.error!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              ElevatedButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        if (_isLogin) {
                          ref.read(authStateProvider.notifier).login(
                                phoneNumber: _phoneController.text,
                                password: _passwordController.text,
                              );
                        } else {
                          // Validate password confirmation
                          if (_passwordController.text != _confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Пароли не совпадают'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.only(top: 80, left: 16, right: 16),
                              ),
                            );
                            return;
                          }
                          
                          ref.read(authStateProvider.notifier).register(
                                phoneNumber: _phoneController.text,
                                displayName: _nameController.text,
                                password: _passwordController.text,
                                inviteCode: _inviteCodeController.text,
                              );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
              ),
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? 'Нет аккаунта? Зарегистрироваться'
                      : 'Уже есть аккаунт? Войти',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


