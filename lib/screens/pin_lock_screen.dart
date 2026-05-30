import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../services/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'main_shell_screen.dart';

class PinLockScreen extends StatefulWidget {
  final bool isSetup; // true: setting up PIN, false: logging in

  const PinLockScreen({super.key, required this.isSetup});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredCode = '';
  String _firstEnteredCode = ''; // For confirming in setup mode
  bool _isConfirming = false;

  final LocalAuthentication _auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck;
        _isBiometricSupported = isSupported;
      });
      // Auto-trigger biometric on login screen
      if (!widget.isSetup && (canCheck || isSupported)) {
        _authenticateBiometric();
      }
    } catch (e) {
      debugPrint('Biometrics check failed: $e');
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'يرجى المصادقة لفتح التطبيق',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        final provider = Provider.of<FinanceProvider>(context, listen: false);
        provider.login();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShellScreen()),
        );
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
    }
  }

  void _onNumberTap(String number) {
    if (_enteredCode.length < 4) {
      setState(() {
        _enteredCode += number;
      });
    }

    if (_enteredCode.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () => _processPin());
    }
  }

  void _onDeleteTap() {
    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    }
  }

  void _processPin() {
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    if (widget.isSetup) {
      if (!_isConfirming) {
        // First entry done
        setState(() {
          _firstEnteredCode = _enteredCode;
          _enteredCode = '';
          _isConfirming = true;
        });
      } else {
        // Confirmation entry done
        if (_enteredCode == _firstEnteredCode) {
          provider.setPinCode(_enteredCode);
          Helpers.showSnackBar(context, 'تم تعيين الرمز السري بنجاح');
          Navigator.pop(context);
        } else {
          Helpers.showSnackBar(context, 'الرموز غير متطابقة، حاول مرة أخرى', isError: true);
          setState(() {
            _enteredCode = '';
            _firstEnteredCode = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Login mode
      if (_enteredCode == provider.pinCode) {
        provider.login();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShellScreen()),
        );
      } else {
        Helpers.showSnackBar(context, 'الرمز السري خاطئ، حاول مرة أخرى', isError: true);
        setState(() {
          _enteredCode = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = provider.isDarkMode;

    String instructionText = '';
    if (widget.isSetup) {
      instructionText = _isConfirming ? 'أدخل الرمز السري مرة أخرى للتأكيد' : 'أدخل رمز سري جديد (4 أرقام)';
    } else {
      instructionText = 'أدخل الرمز السري لفتح التطبيق';
    }

    return Scaffold(
      backgroundColor: isDark ? AppConstants.darkBg : AppConstants.lightBg,
      appBar: widget.isSetup
          ? AppBar(
              title: const Text('تعيين رمز الأمان'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: isDark ? Colors.white : Colors.black,
            )
          : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Title & Instruction
            Text(
              provider.ceremonyName,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? AppConstants.accentColor : AppConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              instructionText,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 40),

            // Dots Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = index < _enteredCode.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? (isDark ? AppConstants.accentColor : AppConstants.primaryColor)
                        : Colors.transparent,
                    border: Border.all(
                      color: isDark ? Colors.white30 : Colors.black26,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),

            // Custom Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9']
                  ]) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map((digit) => _buildKeypadButton(digit)).toList(),
                    ),
                    const SizedBox(height: 15),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Delete Button
                      _buildKeypadButton('del', icon: Icons.backspace_outlined),
                      _buildKeypadButton('0'),
                      // Fingerprint icon
                      _buildKeypadButton(
                        'biometric',
                        icon: Icons.fingerprint,
                        isDisabled: widget.isSetup || !(_canCheckBiometrics || _isBiometricSupported),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String value, {IconData? icon, bool isDisabled = false}) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isDark = provider.isDarkMode;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              if (value == 'del') {
                _onDeleteTap();
              } else if (value == 'biometric') {
                _authenticateBiometric();
              } else {
                _onNumberTap(value);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled
              ? Colors.transparent
              : (isDark ? AppConstants.cardDarkBg : Colors.white),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: isDisabled 
                      ? Colors.transparent 
                      : (isDark ? Colors.white70 : Colors.black87),
                  size: 26,
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }
}
