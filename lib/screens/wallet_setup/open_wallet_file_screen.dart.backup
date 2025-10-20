import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/theme.dart';
import '../auth/pin_entry_screen.dart';

class OpenWalletFileScreen extends StatefulWidget {
  const OpenWalletFileScreen({super.key});

  @override
  State<OpenWalletFileScreen> createState() => _OpenWalletFileScreenState();
}

class _OpenWalletFileScreenState extends State<OpenWalletFileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickWalletFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['wallet', 'keys', 'dat'],
          dialogTitle: 'Select XF₲ Wallet File',
          withData: false,
          withReadStream: false,
          allowMultiple: false,
        );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.path != null) {
          // Additional validation for file extension
          final fileName = file.name.toLowerCase();
          final validExtensions = ['.wallet', '.keys', '.dat'];
          final hasValidExtension = validExtensions.any((ext) => fileName.endsWith(ext));

          if (!hasValidExtension) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a valid wallet file (.wallet, .keys, or .dat)'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
            return;
          }

          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to access selected file path'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  bool _validateWalletFile() {
    if (_selectedFilePath == null) return false;

    final file = File(_selectedFilePath!);

    // Check if file exists and is readable
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file does not exist'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return false;
    }

    // Check file size (reasonable wallet file size)
    final fileSize = file.lengthSync();
    if (fileSize == 0 || fileSize > 10 * 1024 * 1024) { // Max 10MB
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid wallet file size'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return false;
    }

    return true;
  }

  void _openWallet() async {
    if (!_validateWalletFile()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual wallet file parsing and loading
      // This would involve:
      // 1. Reading and parsing the wallet file
      // 2. Extracting keys and wallet data
      // 3. Validating the wallet integrity
      // 4. Setting up wallet in wallet provider
      // 5. Navigating to PIN setup

      await Future.delayed(const Duration(seconds: 2)); // Simulate processing

      if (mounted) {
        // Navigate to PIN entry screen for wallet setup
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinEntryScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open wallet: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Open Wallet File',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.folder_open,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Open Wallet File',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Select a wallet file from your device to open an existing XF₲ wallet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // File selection area
                    GestureDetector(
                      onTap: _pickWalletFile,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFilePath != null
                                ? AppTheme.primaryColor.withOpacity(0.5)
                                : AppTheme.textMuted.withOpacity(0.3),
                            width: _selectedFilePath != null ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFilePath != null
                                  ? Icons.file_present
                                  : Icons.file_upload,
                              size: 48,
                              color: _selectedFilePath != null
                                  ? AppTheme.primaryColor
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilePath != null
                                  ? 'File Selected'
                                  : 'Tap to Select Wallet File',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _selectedFilePath != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _selectedFileName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Supported formats: .wallet, .keys, .dat',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Open wallet button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _selectedFilePath == null)
                            ? null
                            : _openWallet,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_open,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Open Wallet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // File info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.textMuted.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supported Wallet Files',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildFileTypeInfo(
                            'XF₲ Wallet (.wallet)',
                            'Standard XF₲ wallet file containing encrypted keys',
                          ),
                          const SizedBox(height: 8),
                          _buildFileTypeInfo(
                            'Key File (.keys)',
                            'File containing view and spend keys',
                          ),
                          const SizedBox(height: 8),
                          _buildFileTypeInfo(
                            'Legacy Format (.dat)',
                            'Older wallet format compatibility',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Security notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: AppTheme.warningColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ensure your wallet file is from a trusted source. Back up your wallet file regularly and keep it secure.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.warningColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTypeInfo(String fileType, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          color: AppTheme.primaryColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileType,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

