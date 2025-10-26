// Basic Flutter widget test for XF₲ Wallet

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xfg_wallet/main.dart';

void main() {
  testWidgets('XF₲ Wallet app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const XFGWalletApp());

    // Verify that our app starts with the splash screen
    expect(find.text('XF₲ WALLET'), findsOneWidget);
    expect(find.text('Privacy Blockchain Banking'), findsOneWidget);
  });
}
