# Security Policy

The Sancta Via development team takes security seriously. We are committed to protecting our users' data and providing a safe and trustworthy experience.

## Reporting a Vulnerability

If you discover a security vulnerability within any of the Sancta Via applications or packages, please report it to us immediately.

**DO NOT** report security vulnerabilities through public GitHub issues.

Instead, please send an email to `security@example.com` (Note: This is a placeholder; a real contact email should be established).

Please include the following with your report:
*   A description of the vulnerability and its potential impact.
*   The package(s) and specific files affected.
*   Steps to reproduce the vulnerability.
*   Any proof-of-concept code.

We will work with you to resolve the issue promptly and will publicly acknowledge your contribution if you wish.

## Security Analysis & Findings (as of 2024-11-24)

A security analysis of the monorepo was conducted after migration. The following areas were investigated: hardcoded secrets, data storage practices, network security, and URL handling.

### High Priority Findings

#### 1. Insecure Data Storage with `shared_preferences`

*   **Observation:** The `shared_preferences` package is used extensively across all applications in the monorepo to store application settings, user progress (e.g., reading plans), and other non-critical data.

*   **Vulnerability:** The `shared_preferences` package is **not designed for secure data storage**. It saves data in unencrypted plain text files (XML on Android, plists on iOS) in the application's sandbox. On a rooted or jailbroken device, this data can be easily accessed and read by the user or other malicious applications.

*   **Impact:** While currently used for user preferences, this poses a significant **privacy risk**. If any personally identifiable information (PII) or other sensitive data (e.g., journal entries, prayer lists, examination history) were to be stored using this method, it would be completely exposed on a compromised device.

*   **Recommendation:**
    1.  **Audit Data:** Immediately audit all data being stored via `shared_preferences` to ensure it contains no sensitive or private information.
    2.  **Use Secure Alternatives:** For any data that is sensitive, private, or could be linked to a user's identity, use the `flutter_secure_storage` package instead. This package utilizes the platform-provided Keystore (Android) and Keychain (iOS) to store data in an encrypted format.
    3.  **Future Development:** Establish a clear policy that `shared_preferences` is only to be used for non-sensitive, ephemeral data, while `flutter_secure_storage` must be used for all user-specific tokens, credentials, and private information.

### Medium Priority Findings

#### 2. Auditing of URL Launching

*   **Observation:** The `url_launcher` package is used in the `sancta_via_shared_ui` package, primarily for linking to external pages like privacy policies or support sites.

*   **Vulnerability:** Launching URLs, especially if they are dynamically constructed from external sources, can potentially lead to XSS or phishing attacks if not handled carefully.

*   **Impact:** A malicious URL could direct a user to a phishing site to steal credentials or to a site that attempts to exploit browser vulnerabilities.

*   **Recommendation:**
    1.  **Audit Usage:** Review all calls to `url_launcher` across all packages in the monorepo.
    2.  **Enforce Hardcoded URLs:** Ensure that all launched URLs are hardcoded, constant strings within the application and cannot be influenced by remote or user-provided data.
    3.  **Validate URLs:** If dynamic URLs are absolutely necessary, implement strict validation to ensure they conform to an expected format and domain whitelist.

### General Recommendations

*   **Dependency Auditing:** Regularly audit all third-party dependencies in `pubspec.yaml` for known security vulnerabilities. Use tools like the `dart pub outdated` command and check against vulnerability databases.
*   **Platform-Specific Hardening:** Continuously review and apply platform-specific security best practices for Android and iOS, such as those recommended by OWASP Mobile Application Security (MASVS).
*   **Monorepo Benefits:** The monorepo structure allows for centralized security updates - when a vulnerability is found in a shared package, it can be fixed once and propagated to all dependent applications through Melos.
