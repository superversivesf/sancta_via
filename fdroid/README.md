# F-Droid `fdroiddata` metadata — 7 apps

> Drafts for the packaging MR to <https://gitlab.com/fdroid/fdroiddata>.
> Generated 2026-11-17. Verify before submission:
>
> 1. `commit:` pins — set to the release tag (or HEAD sha) of the branch the
>    build server should use; tags must exist on the PUBLIC repo first.
> 2. Flutter version — keep `3.47.8` in sync with `.fvmrc`/the machines
>    building locally; the explicit `$$flutter$$` srclib form is REQUIRED
>    (the plain `gradle:` shorthand cannot work: our `settings.gradle.kts`
>    needs `flutter.sdk` from `local.properties`).
> 3. `versionCode` = the `+N` in each pubspec (all currently 2).
> 4. License: MIT (root + per-app LICENSE files).
> 5. F-Droid builds sign with their own key; installs will NOT cross-upgrade
>    from side-loaded releases. Documented and accepted.
>
> Suggested tag scheme: `releases/<app>/v<version>+<build>` per app, with
> `UpdateCheckMode: Tags` and the pattern below.

Common preamble per metadata file:

```yaml
License: MIT
RepoType: git
Repo: https://github.com/superversivesf/sancta_via
```
