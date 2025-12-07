# WawApp — Specify Integration Rules for Amazon Q

This project uses SPECIFY as the primary execution layer.

## Amazon Q Must:
- Prefer calling `.\spec.ps1` tasks for all CLI interactions.
- Avoid raw Flutter/Dart commands.
- Always check `.specify/` configs first before suggesting build steps.
- Use the project's automated tasks pipeline for:
  - FCM verification
  - Flutter doctor
  - Build checks
  - Environment checks
