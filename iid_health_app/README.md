# IID Health App

Onboarding + Authentication flow prototype based on existing IID codebase.

Flow: Onboarding intro → Terms consent → Login/Register → Initial profile input → Device connect guide.

## Run (Windows PowerShell)

Before first run on Windows, enable Developer Mode to allow Flutter plugins (symlink support):

1. Open Developer Settings:

```powershell
start ms-settings:developers
```

2. Turn on "Developer Mode".

Then, fetch packages and run:

```powershell
cd iid_health_app
flutter pub get
flutter run
```

If you prefer a specific platform:

```powershell
flutter run -d windows
```

## Notes

- Auth is mocked locally using SharedPreferences for now (no backend).
- You can replace the login/register pages later with your existing API-based versions under `IID/lib/User/`.
- State flags used:
	- `onboarding_intro_done`, `onboarding_terms_agreed`, `is_logged_in`, `profile_completed`.
- Stored profile fields: `profile_height`, `profile_weight`, `profile_bodyfat`, `profile_goal`.

## Next steps

- Swap mock auth with real backend and QR login if needed.
- Add a proper dashboard/home after device guide.
- Migrate existing Checklist/Solution pages into this app as features.
