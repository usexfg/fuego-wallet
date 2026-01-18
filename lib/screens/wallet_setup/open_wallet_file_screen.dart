import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../utils/theme.dart';
import '../../providers/wallet_provider_hybrid.dart';
import '../../models/network_config.dart';
import '../../services/wallet_daemon_service.dart';
import '../auth/pin_setup_screen.dart';

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
  String? _errorMessage;
  WalletProviderHybrid? _walletProvider;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeWalletProvider();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  void _initializeWalletProvider() {
    _walletProvider = WalletProviderHybrid();
  }

  /// Prompt user for wallet password
  Future<String?> _promptForPassword() async {
    String? password;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final passwordController = TextEditingController();

        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'Wallet Password Required',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This wallet file is password protected. Please enter the password to unlock it.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  Navigator.of(context).pop(passwordController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    ).then((value) => password = value);

    return password;
  }





  Future<void> _pickWalletFile() async {
    try {
      // Try to open common wallet directories
      String? initialDirectory = await _getDefaultDirectory();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wallet', 'keys', 'dat'],
        dialogTitle: 'Select XF₲ Wallet File',
        initialDirectory: initialDirectory,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        await _processSelectedFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error selecting file: $e';
        });
      }
    }
  }

  Future<String?> _getDefaultDirectory() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getExternalStorageDirectory();
        return directory?.path;
      } else {
        // Desktop - try common wallet locations
        final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (homeDir != null) {
          final commonPaths = [
            path.join(homeDir, 'Documents', 'XF₲ Wallet'),
            path.join(homeDir, 'Documents', 'Fuego Wallet'),
            path.join(homeDir, 'Documents', 'Wallets'),
            path.join(homeDir, 'Desktop'),
            path.join(homeDir, 'Downloads'),
            path.join(homeDir, 'Documents'),
          ];

          for (final dirPath in commonPaths) {
            if (await Directory(dirPath).exists()) {
              return dirPath;
            }
          }
        }
      }
    } catch (e) {
      // Fallback to current directory
    }
    return null;
  }

  Future<void> _processSelectedFile(String filePath) async {
    if (!mounted) return;

    setState(() {
      _selectedFilePath = filePath;
      _selectedFileName = path.basename(filePath);
      _errorMessage = null;
    });

    // Quick validation
    if (!_quickValidateFile()) {
      return;
    }
  }

  bool _quickValidateFile() {
    if (_selectedFilePath == null) return false;

    final file = File(_selectedFilePath!);

    // Check if file exists
    if (!file.existsSync()) {
      setState(() {
        _errorMessage = 'Selected file does not exist';
      });
      return false;
    }

    // Check file size
    final fileSize = file.lengthSync();
    if (fileSize == 0) {
      setState(() {
        _errorMessage = 'File is empty';
      });
      return false;
    }

    if (fileSize > 50 * 1024 * 1024) { // Max 50MB
      setState(() {
        _errorMessage = 'File is too large (max 50MB)';
      });
      return false;
    }

    return true;
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _errorMessage = null;
    });
  }

  void _openWallet() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Final validation
      if (!_quickValidateFile()) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Initialize wallet daemon service with proper node address
      final networkConfig = NetworkConfig.mainnet;
      await WalletDaemonService.initialize(
        daemonAddress: networkConfig.defaultSeedNode.split(':')[0],
        daemonPort: networkConfig.daemonRpcPort,
        networkConfig: networkConfig,
      );

      // Prompt user for wallet password immediately
      final password = await _promptForPassword();
      if (password == null) {
        // User cancelled password entry
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Try to open wallet with provided password
      final success = await _walletProvider!.openWallet(
        walletPath: _selectedFilePath!,
        password: password,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Failed to open wallet. The password may be incorrect or the file may be corrupted.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        // Navigate to PIN setup for existing wallet
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinSetupScreen(
              mnemonic: '', // Empty mnemonic indicates existing wallet
              isRestore: true, // Indicates this is for an existing wallet
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to open wallet: $e';
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
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Open Wallet',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Text(
                  'Open Your XF₲ Wallet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select your existing wallet file to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Main content
                Expanded(
                  child: _buildFileSelectionArea(),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error,
                          color: AppTheme.errorColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // File type info
                const SizedBox(height: 16),
                _buildFileTypeInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelectionArea() {
    if (_selectedFilePath != null) {
      return _buildSelectedFileWidget();
    } else {
      return _buildFilePickerWidget();
    }
  }

  Widget _buildFilePickerWidget() {
    return GestureDetector(
      onTap: _pickWalletFile,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.textMuted.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open,
                size: 64,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Wallet File',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supported formats: .wallet, .keys, .dat',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickWalletFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'Wallet file selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFileName!,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.clear),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(
                    color: AppTheme.textMuted.withOpacity(0.3),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _openWallet,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isLoading ? 'Opening...' : 'Open Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileTypeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textMuted.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supported Wallet Files',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildFileTypeRow(
            'XF₲ Wallet (.wallet)',
            'Standard XF₲ wallet file',
          ),
          const SizedBox(height: 8),
          _buildFileTypeRow(
            'Key File (.keys)',
            'View and spend keys file',
          ),
          const SizedBox(height: 8),
          _buildFileTypeRow(
            'Legacy Format (.dat)',
            'Older wallet format',
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(
                Icons.info,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Files are processed locally and never uploaded.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileTypeRow(String fileType, String description) {
    return Row(
      children: [
        const Icon(
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _walletProvider?.dispose();
    super.dispose();
  }
}
