# WawApp Project Constitution

## Project Overview
Flutter monorepo containing:
- **Client App** (`apps/wawapp_client/`) - Customer-facing mobile application
- **Driver App** (`apps/wawapp_driver/`) - Driver-facing mobile application  
- **Admin Panel** - Web-based administrative interface

## Technology Stack

### Core Framework
- **Flutter**: 3.35.x stable
- **Dart SDK**: ^3.5

### Android Build System
- **Gradle**: 8.7
- **Android Gradle Plugin (AGP)**: 8.4.2
- **JDK**: 17

### Firebase Services
```yaml
firebase_core: latest
firebase_auth: latest
cloud_firestore: latest
firebase_app_check: latest
firebase_messaging: latest
```

### Required Packages
```yaml
# State Management & Navigation
riverpod: latest
go_router: latest

# Internationalization
intl: latest

# Location & Maps
geolocator: latest
google_maps_flutter: latest

# Code Generation & Data Classes
freezed: latest
json_serializable: latest
equatable: latest
```

## Project Structure

### Folder Architecture
```
apps/
├── wawapp_client/
│   └── lib/
│       ├── core/           # Core utilities, constants, themes
│       ├── features/       # Feature-based modules
│       │   └── <feature>/  # auth, home, profile, etc.
│       ├── services/       # API, Firebase, external services
│       ├── shared/         # Shared widgets, models, utils
│       └── l10n/          # Localization files
├── wawapp_driver/
│   └── lib/               # Same structure as client
└── admin_panel/
    └── web/               # Admin web interface
```

### Feature Module Structure
```
features/<feature>/
├── data/          # Repositories, data sources, models
├── domain/        # Entities, use cases, repository interfaces
├── presentation/  # Pages, widgets, providers
└── <feature>.dart # Feature barrel export
```

## Code Quality Standards

### Formatting & Analysis
- **Mandatory**: All code must pass `dart format .` before commit
- **Mandatory**: All code must pass `flutter analyze` before commit
- **Configuration**: Use project-wide `analysis_options.yaml`

### Testing Requirements
- **Widget Tests**: Golden tests for UI components
- **Unit Tests**: Business logic and data layer coverage
- **Coverage**: Minimum 70% for changed files
- **Location**: Tests in `test/` directory mirroring `lib/` structure

## Security Standards

### Firebase App Check
- **Production**: Play Integrity API for release builds
- **Development**: Debug tokens documented in `.specify/debug-tokens.md`
- **Implementation**: Required for all Firebase service calls

### Authentication
- Firebase Auth with proper session management
- Secure token storage using Flutter Secure Storage
- Biometric authentication where supported

## Internationalization (i18n)

### Supported Languages
- Arabic (ar)
- English (en) - default
- French (fr)

### Implementation
- Use `flutter gen-l10n` for code generation
- ARB files in `lib/l10n/` directory
- RTL support for Arabic language

### Configuration
```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

## Git Workflow

### Branch Naming Convention
- **Features**: `feat/feature-name`
- **Bug Fixes**: `fix/bug-description`
- **Maintenance**: `chore/task-description`

### Release Tagging
- Format: `vMAJOR.MINOR.PATCH`
- Example: `v1.2.3`
- Follow semantic versioning

### Commit Standards
- Conventional commits format
- Must pass all quality checks before push

## Build & Release Process

### Local Development
```bash
# Debug builds
flutter build apk --debug
flutter build ios --debug

# Release builds
flutter build apk --release
flutter build ios --release
```

### Environment Configuration
- Development, staging, and production environments
- Environment-specific Firebase configurations
- Secure handling of API keys and secrets

## Logging Standards

### Structured Logging
- **Format**: JSON structured logs
- **Required Modules**:
  - Application initialization
  - Authentication flows
  - Location services
  - Error tracking

### Log Levels
- `DEBUG`: Development debugging
- `INFO`: General application flow
- `WARN`: Recoverable issues
- `ERROR`: Application errors
- `FATAL`: Critical failures

## Environment Parity

### Development Machine Requirements
All developers must maintain identical versions:
- **Flutter**: 3.35.x stable
- **Dart SDK**: ^3.5
- **Gradle**: 8.7
- **JDK**: 17
- **Android Studio**: Latest stable
- **VS Code**: Latest with Flutter/Dart extensions

### Version Verification
```bash
# Verify versions before development
flutter --version
java -version
gradle --version
```

## Performance Standards

### App Performance
- Cold start time: < 3 seconds
- Hot reload: < 1 second
- Memory usage: < 150MB baseline
- APK size: < 50MB per app

### Code Performance
- Avoid blocking UI thread
- Implement proper state management
- Optimize image loading and caching
- Use lazy loading for large lists

## Documentation Requirements

### Code Documentation
- Public APIs must have dartdoc comments
- Complex business logic requires inline comments
- README files for each major feature

### Architecture Documentation
- Decision records for major architectural choices
- API documentation for backend integrations
- Deployment and configuration guides

## Changelog

### Version History

#### v1.0.0 (TBD)
- Initial project constitution
- Core architecture established
- Development standards defined

### Change Log Format
```markdown
## [Version] - YYYY-MM-DD
### Added
- New features

### Changed
- Modified functionality

### Fixed
- Bug fixes

### Removed
- Deprecated features
```

## Compliance & Monitoring

### Quality Gates
- All commits must pass CI/CD pipeline
- Code review required for all changes
- Automated testing on pull requests
- Security scanning for dependencies

### Monitoring
- Application performance monitoring
- Error tracking and alerting
- User analytics and crash reporting
- Firebase performance monitoring

---

**Last Updated**: 2024-12-19
**Version**: 1.0.0
**Maintainers**: Development Team