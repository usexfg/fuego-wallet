# Web Gateway (`cold.html`) Integration Analysis & Recommendations

## Overview
The goal is to seamlessly integrate the `cold.html` web gateway (from the `usexfg.org` repo) into the Fuego Wallet so that users can easily claim HEAT tokens without friction.

## Analysis of Current Architecture
1. Fuego Wallet is a Flutter-based cross-platform desktop application.
2. It interacts with smart contracts via Web3 services (like `web3_cold_service.dart`) and now includes the logic to generate STARK/Merkle proofs through CLI binaries (`xfg-stark` and `fuego-prover`).
3. Users currently generate proofs directly inside the desktop app. If `cold.html` is meant to be the *front-end* interface for claiming HEAT, there are a couple of ways it can be used.

## Recommended Approaches

### Approach 1: Embedded WebView (Recommended for Seamless UX)
Integrate `cold.html` directly into the Fuego Wallet using the `webview_flutter` or `desktop_webview_window` package.
- **Pros:** Users never leave the app. The Fuego Wallet generates the proofs in Dart/C++ and passes them via JavaScript injection into the webview holding `cold.html`. The web interface handles the actual smart contract interaction via a browser wallet like MetaMask or WalletConnect.
- **Cons:** Requires adding a webview dependency, which can sometimes be tricky on Linux/Windows desktops.

### Approach 2: Deep Linking & External Browser (Easiest to Maintain)
The Fuego Wallet generates the `BundledBurnProof` (STARK + Merkle) and provides a "Claim via Gateway" button. Clicking this button opens the system's default browser to `https://usexfg.org/cold.html?proofHash=...&amount=...`.
- **Pros:** Very simple to implement. Leverages the user's existing web3 browser extensions (like MetaMask) effortlessly.
- **Cons:** User context switches out of the desktop app to their browser.

### Approach 3: Fully Native (Bypass `cold.html`)
Use Fuego Wallet's existing `ContractService` and `Web3Client` to sign and submit the HEAT claim transactions natively.
- **Pros:** Pure native experience. No browser needed.
- **Cons:** Users must trust the desktop app with their Ethereum private keys (or the app must integrate WalletConnect natively).

## Final Recommendation
For the fastest and most reliable setup, **Approach 2 (External Browser with URL Parameters)** is recommended initially. It offloads the Web3 signature process to the user's trusted browser wallet while relying on the desktop app solely for proof generation.

Once Fuego Wallet implements full WalletConnect v2 support natively, Fuego Wallet can transition to **Approach 3** to submit claims without needing `cold.html` at all.
