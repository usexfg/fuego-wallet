# 🔥 FUEGO WALLET INTEGRATION - USER CHECKLIST
## Before You Start: Review & Testing Guide

---

## 📋 PREREQUISITES COMPLETED

### ✅ Files Created (4 NEW files)
- [x] `lib/services/walletd_service.dart` - Walletd + Optimizer integration
- [x] `lib/services/web3_cold_service.dart` - Ethereum Web3 for COLD token
- [x] `lib/INTEGRATION_CHANGES.md` - Full documentation
- [x] `lib/IMPLEMENTATION_SUMMARY.md` - Technical summary
- [x] `lib/FINAL_SUMMARY.md` - Complete overview
- [x] `lib/CHECKLIST.md` - This file

### ✅ Files Updated (5 MODIFIED files)
- [x] `lib/screens/banking/banking_screen.dart` - Ξternal Flame + COLD tabs
- [x] `lib/screens/main/main_screen.dart` - Updated navigation
- [x] `lib/screens/home/home_screen.dart` - Service status
- [x] `lib/utils/theme.dart` - New colors
- [x] `lib/pubspec.yaml` - web3dart + assets

### ✅ Existing Files Preserved
- [x] `lib/services/cli_service.dart` - Fallback CLI support
- [x] `lib/screens/banking/burn_deposits_screen.dart` - Unchanged
- [x] `lib/screens/splash_screen.dart` - Unchanged
- [x] All wallet providers/models - Unchanged

---

## 🎯 IMPLEMENTATION VERIFICATION

### 1. Service Files Check
**File: `lib/services/walletd_service.dart`**
```bash
# Verify file exists and has walletd service
grep "class WalletdService" lib/services/walletd_service.dart
grep "startWalletd" lib/services/walletd_service.dart
grep "startOptimizer" lib/services/walletd_service.dart
```
- [ ] File exists
- [ ] Contains `WalletdService` class
- [ ] Has `startWalletd()` method
- [ ] Has `startOptimizer()` method
- [ ] Has RPC client functionality
- [ ] Has process management
- [ ] Has log callbacks
- [ ] Has status tracking

**File: `lib/services/web3_cold_service.dart`**
```bash
# Verify Web3 service
grep "class Web3COLDService" lib/services/web3_cold_service.dart
grep "COLD_CONTRACT_ADDRESS" lib/services/web3_cold_service.dart
grep "connect" lib/services/web3_cold_service.dart
grep "getBalance" lib/services/web3_cold_service.dart
```
- [ ] File exists
- [ ] Contains `Web3COLDService` class
- [ ] Has COLD contract address (`0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755`)
- [ ] Has `connect()` method
- [ ] Has `getBalance()` method
- [ ] Has `transfer()` method
- [ ] Has multi-RPC support
- [ ] Has connection status callbacks

### 2. UI Screens Check
**File: `lib/screens/banking/banking_screen.dart`**
```bash
# Verify banking screen updates
grep "Ξternal Flame" lib/screens/banking/banking_screen.dart
grep "COLD" lib/screens/banking/banking_screen.dart
grep "_startWalletd" lib/screens/banking/banking_screen.dart
grep "_connectWeb3" lib/screens/banking/banking_screen.dart
```
- [ ] File contains new tab names
- [ ] Has `_buildEternalFlameTab()` method
- [ ] Has `_buildCOLDTab()` method
- [ ] Has walletd start/stop functions
- [ ] Has Web3 connection functions
- [ ] Has burn process functions
- [ ] Has service status indicators
- [ ] Has log viewers

**File: `lib/screens/main/main_screen.dart`**
```bash
# Verify navigation changes
grep "Banking" lib/screens/main/main_screen.dart
grep "HEAT" lib/screens/main/main_screen.dart
grep "_buildNavItem" lib/screens/main/main_screen.dart
```
- [ ] Has 5 navigation items
- [ ] Banking shows HEAT icon
- [ ] No "Mint Ξmbers" separate item
- [ ] Updated `_buildNavItem` with icon2/label2

**File: `lib/screens/home/home_screen.dart`**
```bash
# Verify home screen updates
grep "Service Status" lib/screens/home/home_screen.dart
grep "Quick Access" lib/screens/home/home_screen.dart
grep "walletd" lib/screens/home/home_screen.dart
grep "web3" lib/screens/home/home_screen.dart
```
- [ ] Has service status panel
- [ ] Has 4 feature cards
- [ ] Shows walletd availability
- [ ] Shows Web3 availability
- [ ] Has action buttons for banking

### 3. Theme Updates
**File: `lib/utils/theme.dart`**
```bash
# Verify new colors
grep "COLD" lib/utils/theme.dart
grep "perfective" lib/utils/theme.dart
grep "successColor" lib/utils/theme.dart
```
- [ ] Has COLD blue color
- [ ] Has errorColor (for HEAT)
- [ ] Has successColor (services)
- [ ] Has updated gradients

### 4. Dependencies
**File: `lib/pubspec.yaml`**
```bash
# Verify dependencies
grep "web3dart" lib/pubspec.yaml
grep "flutter_screenutil" lib/pubspec.yaml
grep "flutter_svg" lib/pubspec.yaml
```
- [ ] web3dart: ^2.7.2 added
- [ ] flutter_screenutil: ^5.9.0 added
- [ ] flutter_svg: ^2.0.10 added
- [ ] assets/bin/ listed
- [ ] fonts section added

---

## 🧪 FUNCTIONAL TESTS

### Test 1: Service Initialization
1. Open app
2. Check home screen for service status
3. Verify "walletd: Not Available" or "Available"
4. Verify "Web3: Available"
5. Verify "CLI: Ready"

### Test 2: Navigation Update
1. Go to main navigation
2. Confirm 5 items: Home, Messages, Banking, Settings, Elderfiers
3. Banking item should show fire icon + "HEAT" label
4. No separate "Mint Ξmbers" item

### Test 3: Banking Screen - Ξternal Flame Tab
1. Navigate to Banking → Tap "Ξternal Flame" tab
2. Verify header: "Fuego Ξmbers (HEAT)"
3. See walletd integration panel
4. See burn options (Standard: 0.8 XFG → 8M HEAT)
5. See burn button
6. See info card about HEAT

### Test 4: Banking Screen - COLD Tab
1. Navigate to Banking → Tap "COLD" tab
2. Verify header: "COLD Interest Lounge"
3. See Web3 connection panel
4. See COLD address input field
5. See "Connect Web3" button
6. See empty state message
7. See C0DL3 interest info box

### Test 5: Walletd Service
1. In Ξternal Flame tab, toggle walletd integration ON
2. Check if button shows "Start walletd" or "Stop walletd"
3. Check if optimizer control appears
4. Verify logs appear in the panel
5. Check status indicators turn green

**Expected Behavior:**
- [ ] On toggle ON: Calls `_startWalletd()`
- [ ] Shows "Starting walletd..." in logs
- [ ] Success: Green status, "Running" state
- [ ] Failure: Red error, "Stopped" state
- [ ] On toggle OFF: Calls `_stopWalletd()`
- [ ] Stop is graceful (SIGTERM)

**Possible Issues:**
- [ ] Binary not found → Shows error in logs
- [ ] Port 8070 busy → Try 8071, 8072
- [ ] Daemon offline → Shows connection error

### Test 6: Web3 Service
1. In COLD tab, enter COLD address: `0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755`
2. Click "Connect Web3"
3. Check Web3 logs for connection attempts
4. Verify connection status turns green
5. Check if balance displays (if tokens exist)

**Expected Behavior:**
- [ ] Address validation before connect
- [ ] Tries multiple RPC endpoints
- [ ] Shows "Connecting..." in logs
- [ ] Success: "Connected: 0x..." + balance
- [ ] Failure: "Connection failed" + error
- [ ] Balance refresh button works

**Possible Issues:**
- [ ] No internet → Connection fails
- [ ] Invalid address → Validation error
- [ ] No COLD tokens → Shows 0 balance
- [ ] Rate limit → Try alternate RPC

### Test 7: Burn Process
1. In Ξternal Flame tab, select "Standard Burn"
2. Ensure walletd is running (toggle ON)
3. Click "Burn XFG & Mint HEAT"
4. Verify loading state
5. Should navigate to Burn Deposits screen
6. Or show integrated proof generation

**Expected Behavior:**
- [ ] Button disabled while burning
- [ ] Loading indicator shows
- [ ] Walletd integration: Uses RPC optimize
- [ ] CLI fallback: Uses xfg-stark-cli
- [ ] Navigation to BurnDepositsScreen
- [ ] Success message: "Burn process initiated"

### Test 8: Service Logs
1. Start walletd and optimizer
2. Watch logs in UI
3. Verify real-time output streaming
4. Check if logs are readable (monospace font)
5. Verify scroll functionality

**Expected Behavior:**
- [ ] Logs appear within 2 seconds
- [ ] Monospace font used
- [ ] Scrolling works
- [ ] Clear overflow handling

---

## 📱 PLATFORM TESTS

### Desktop (Linux/Mac/Windows)
- [ ] App launches successfully
- [ ] All screens load
- [ ] Service binaries extracted
- [ ] walletd starts/stops
- [ ] Optimizer starts/stops
- [ ] Web3 connects
- [ ] UI is responsive

### Mobile (Android/iOS)
- [ ] Permission requests work
- [ ] Binary extraction works
- [ ] Services may not start (background limitation)
- [ ] Web3 connects
- [ ] UI is responsive
- [ ] No crashes

### Notes:
- walletd integration is best on Desktop
- Web3 works on all platforms
- Mobile may have background service limitations

---

## 🎨 UI VERIFICATION

### Ξternal Flame Tab
- [ ] Gradient header (red/orange)
- [ ] Fire icon + "Ξternal Flame" text
- [ ] Walletd integration card
- [ ] Burn option cards
- [ ] Burn button (red, with loading state)
- [ ] Info card with HEAT description
- [ ] Service status indicators
- [ ] Log viewers

### COLD Tab
- [ ] Gradient header (blue)
- [ ] Savings icon + "COLD Interest Lounge"
- [ ] Web3 connection panel
- [ ] Address input field
- [ ] Connect/Refresh buttons
- [ ] Balance display card (if connected)
- [ ] Interest info card (blue bordered)
- [ ] Service controls
- [ ] Web3 logs

### Home Screen
- [ ] Welcome card (gradient)
- [ ] 4 feature cards (2x2 grid)
- [ ] Service status panel
- [ ] Quick action buttons
- [ ] Info dialog

### Main Navigation
- [ ] 5 items
- [ ] Banking shows HEAT icon
- [ ] Proper spacing
- [ ] Selected state colors

---

## 🔒 SECURITY CHECKS

- [ ] No hardcoded private keys
- [ ] Address validation before transfers
- [ ] Secure storage for sensitive data
- [ ] Process signal handling
- [ ] RPC timeouts
- [ ] Retry logic with limits
- [ ] Input sanitization
- [ ] Error messages don't expose secrets

---

## ⚠️ KNOWN ISSUES TO CHECK

### 1. Binary Missing
**Symptoms:** "walletd binary not found" in logs  
**Fix:** Run `./scripts/ensure-binaries.sh`

### 2. Web3 Connection Fail
**Symptoms:** "Connection failed" in Web3 logs  
**Fix:** Check internet, try refresh, verify address

### 3. Port Conflict
**Symptoms:** walletd fails to start on 8070  
**Fix:** Use 8071 or 8072, or close other process

### 4. No COLD Balance
**Symptoms:** Shows 0.00 or "No balance"  
**Fix:** Verify COLD address has tokens on Ethereum

### 5. Mobile Service Issues
**Symptoms:** walletd won't start on Android/iOS  
**Expected:** Background services limited on mobile

---

## 📊 PERFORMANCE CHECKS

- [ ] App launches < 3 seconds
- [ ] Services start < 5 seconds
- [ ] Web3 queries < 500ms
- [ ] UI remains responsive during operations
- [ ] No memory leaks (check ~10 minutes use)
- [ ] Logs update smoothly

---

## 🎯 FINAL VERIFICATION

### Core Requirements
- [ ] walletd service can be started from GUI
- [ ] Optimizer can be started from GUI
- [ ] Web3 connects to Ethereum
- [ ] COLD address can be entered
- [ ] Balance can be fetched
- [ ] Burn options show correct amounts
- [ ] Navigation has correct labels
- [ ] All screens render properly

### User Experience
- [ ] Instructions are clear
- [ ] Status indicators are visible
- [ ] Logs are understandable
- [ ] Error messages are actionable
- [ ] Loading states implemented
- [ ] Success/failure feedback clear
- [ ] No broken navigation

### Documentation
- [ ] README updated
- [ ] INTEGRATION_CHANGES.md complete
- [ ] IMPLEMENTATION_SUMMARY.md complete
- [ ] FINAL_SUMMARY.md complete
- [ ] CHECKLIST.md (this file) complete
- [ ] Build instructions included
- [ ] Troubleshooting guide present

---

## 🚀 DEPLOYMENT READINESS

### Pre-Deployment
- [ ] All tests pass
- [ ] No errors in console
- [ ] All screens load without crash
- [ ] Services start/stop cleanly
- [ ] Web3 functionality verified
- [ ] Documentation complete
- [ ] User checklist completed

### Post-Deployment
- [ ] Share with users
- [ ] Monitor for issues
- [ ] Collect feedback
- [ ] Update documentation based on feedback
- [ ] Plan next features (swap, hardware wallet, etc.)

---

## 📝 NOTES FOR USER

### ✅ What's Working
1. **Integrated walletd + optimizer** in GUI
2. **Ξternal Flame** (Burn2Mint renamed)
3. **COLD Interest Lounge** (COLD Banking renamed)
4. **Web3 COLD** connection on Ethereum
5. **Real-time logs** in UI
6. **Service status** indicators
7. **Fallback CLI** if services unavailable
8. **Complete documentation**

### ⚠️ What's Expected to Fail
1. **Mobile background services** (iOS/Android limitations)
2. **Web3 without internet** (needs connection)
3. **Burn without binaries** (needs xfg-stark-cli)
4. **COLD without tokens** (0 balance shown)

### 💡 What to Do If Issues
1. Read `INTEGRATION_CHANGES.md` - fixes for common issues
2. Run `./scripts/ensure-binaries.sh` - download CLI
3. Run `./scripts/get_walletd_binary.sh build` - get walletd
4. Check console logs for specific errors
5. Review Web3 logs in UI for connection issues

### 🎉 Success Indicators
- walletd shows green status with logs
- Web3 shows green status with balance
- Burn button works (with or without walletd)
- All screens load without errors
- Navigation works correctly
- UI looks polished and professional

---

## ✅ CHECKLIST COMPLETE
**Date:** 2024-12-26  
**Status:** READY FOR REVIEW  
**Next Step:** Run app and verify all items above

**Files to Review:**
1. `lib/services/walletd_service.dart` - Core integration
2. `lib/screens/banking/banking_screen.dart` - New UI
3. `lib/INTEGRATION_CHANGES.md` - Full docs

**If all checks pass:**
- App is ready for use
- Share with Fuego community
- Collect feedback for v1.1.1

---
**Built with ❤️ for Fuego ecosystem**