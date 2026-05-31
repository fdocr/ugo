# Deep linking

ugo can act as a **Universal Deep Link (UDL) bounce** server on your own domain, similar to [udl-server](https://github.com/fdocr/udl-server). In-app browsers (Instagram, TikTok, etc.) often block same-domain Universal Links; bouncing through your ugo hostname fixes that.

The bounce endpoint lives at **`/r`** so your marketing homepage (`/`) is never affected—even when a default destination is configured.

## Enable in Site Settings

As a **site admin**, open **Admin → Site Settings → Deep linking (mobile apps)**:

1. Turn on **Enable deep link bounce**.
2. Add **iOS App IDs** (`TEAMID.com.your.bundle`) for `/.well-known/apple-app-site-association`.
3. Optionally add **Android asset links** JSON for `/.well-known/assetlinks.json`.
4. Set **Allowed destination domains** on public hosts (recommended for ugo.cr).
5. Optionally set **Default destination URL** — a bare `GET /r` (no `?r=`) redirects there.

There is no environment variable for the default destination; it is stored in the database like other site settings.

> **Open redirect stance:** with no **Allowed destination domains** set, the bounce forwards to any `https` host. This is an accepted trade-off for a UDL bounce; set an allowlist if you want to restrict targets.

## Usage

Link to:

```text
https://your-ugo-domain.example/r?r=https://app.example.com/path
```

Use `target="_blank"` on marketing pages when possible. All redirects must use `https`.

## Mobile app setup

- **iOS:** Associated Domains capability → `applinks:your-ugo-domain.example`
- **Android:** App Links for the same host; verify `/.well-known/assetlinks.json`

Test on TestFlight or production-signed builds; development profiles may not open Universal Links reliably.

## CDN / Cloudflare

- **Cache** `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` (they change rarely).
- **Bypass cache** for `GET /r` (including `?r=` query strings).

## Plans

On **ugo.cr**, deep linking is included with the **Dedicated** plan (managed instance on your subdomain or custom domain). **Basic** and **Growth** use shared `ugo.cr` short links only. **Self-hosted** installations include all features, including deep linking.
