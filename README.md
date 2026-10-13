# Icarus iOS

Private, personal app for the creator of Icarus. Not for public use; see [LICENSE](LICENSE).

## Build

Every push to `main` runs **Build IPA** in GitHub Actions on a macOS runner and
attaches an unsigned `Icarus.ipa` to the run. Download it from the run page and
install it with Sideloadly (it signs with your Apple ID).

## Data

The app reads the Icarus API over Tailscale. On the Icarus PC:

1. Run `python mobile_api.py` instead of `python run_local.py` (same dashboard,
   plus the `/api/mobile/alerts` route the app needs).
2. Run `tailscale serve --bg 8765` once.
3. In the app's Settings, enter the `https://<pc-name>.<tailnet>.ts.net` address
   Tailscale prints.
