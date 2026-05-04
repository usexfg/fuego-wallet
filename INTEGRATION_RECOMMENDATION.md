# Web Gateway URL Integration Recommendations

Based on an analysis of the overall codebase, here are the recommendations for integrating `usexfg.org/cold.html` as the web gateway for users to easily claim HEAT:

## 1. Banking Screen Implementation (`lib/screens/banking/banking_screen.dart`)

The `BankingScreen` component is the primary interface for managing COLD and HEAT assets.

- **Action Buttons**: Add a new action button labeled "Claim HEAT via Web Gateway" in the `_buildCOLDTab` and `_buildEtherealMintTab` sections.
- **URL Launcher**: Use the `url_launcher` package to open `https://usexfg.org/cold.html` when the button is tapped.
  - The `url_launcher` package is already a dependency as seen in the `pubspec.yaml` output.

```dart
// Example implementation:
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchWebGateway() async {
  final Uri url = Uri.parse('https://usexfg.org/cold.html');
  if (!await launchUrl(url)) {
    // Show error message
  }
}
```

## 2. Configuration Settings (`lib/config/cold_tokens_config.dart` or `lib/models/network_config.dart`)

- **Centralized URL**: Store `https://usexfg.org/cold.html` in a centralized configuration file like `NetworkConfig` or `ColdTokensConfig`.
- **Reasoning**: This makes it easier to update the URL globally without touching UI components.

## 3. Help / Information Modals

- When explaining the COLD Interest Lounge or Ξthereal Mint, include a direct link to the web gateway.
- For example, if users have difficulty navigating the native interface, provide the web gateway as an alternative option: "Having trouble? Try our [Web Gateway](https://usexfg.org/cold.html) to claim your HEAT."

## Summary

The simplest and most effective approach is to integrate a "Launch Web Gateway" button within the `BankingScreen` that utilizes the `url_launcher` package, pointing to the designated `https://usexfg.org/cold.html` URL.
