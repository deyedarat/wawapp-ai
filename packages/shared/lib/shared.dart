/// Shared package for WawApp laundry management system.
///
/// Contains models, services, localization, and utilities shared between
/// the Laundry Owner App and Customer App.
library shared;

// Models
export 'models/user_model.dart';
export 'models/order_model.dart';
export 'models/order_item_model.dart';
export 'models/rating_model.dart';

// Services
export 'services/auth_service.dart';
export 'services/firestore_service.dart';
export 'services/notification_service.dart';
export 'services/messaging_service.dart';

// Localization
export 'localization/app_localizations.dart';
export 'localization/l10n.dart';

// Constants
export 'constants/app_constants.dart';
export 'constants/firestore_paths.dart';

// Utils
export 'utils/validators.dart';
export 'utils/formatters.dart';
export 'utils/extensions.dart';

// Widgets
export 'widgets/loading_widget.dart';
export 'widgets/error_widget.dart';
export 'widgets/status_badge.dart';
export 'widgets/phone_input_field.dart';
