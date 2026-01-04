# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email the maintainer directly at: **albayrak.serdar8@gmail.com**
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment:** We will acknowledge receipt within 48 hours
- **Investigation:** We will investigate and provide updates within 7 days
- **Resolution:** We aim to resolve critical issues within 30 days
- **Disclosure:** We will coordinate disclosure timing with you

### Scope

The following are in scope:
- The ScreenCapture application
- Build and distribution processes
- Documentation that could lead to security issues

The following are out of scope:
- Third-party dependencies (report to their maintainers)
- Social engineering attacks
- Physical attacks

## Security Best Practices

When using ScreenCapture:

1. **Permissions:** Only grant Screen Recording permission if you trust the app
2. **Downloads:** Only download from official releases on GitHub
3. **Updates:** Keep the app updated to receive security fixes

## Security Features

ScreenCapture includes these security considerations:

- **Local Processing:** All screenshots are processed locally
- **No Network:** The app does not transmit data externally
- **Permission-Based:** Requires explicit macOS Screen Recording permission
- **No Persistent Storage:** Screenshots are only saved when you explicitly save them
