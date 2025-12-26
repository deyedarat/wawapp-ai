import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';
import '../../core/models/shipment_type.dart';
import '../shipment_type/shipment_type_provider.dart';
import '../map/pick_route_controller.dart';
import '../map/places_autocomplete_sheet.dart';
import '../map/saved_location_selector_sheet.dart';
import '../quote/providers/quote_provider.dart';
import '../quote/models/latlng.dart' as quote_latlng;
import '../../core/geo/distance.dart';
import '../../core/pricing/pricing.dart';
import '../../core/location/location_service.dart';
import '../map/providers/district_layer_provider.dart';
import '../../core/maps/safe_camera_helper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SafeCameraMixin {
  static const CameraPosition _nouakchott = CameraPosition(
    target: LatLng(18.0735, -15.9582),
    zoom: 14.0,
  );
  bool _hasLocationPermission = false;
  String? _errorMessage;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  bool _hasFittedBounds = false; // Track if we've already fitted bounds

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initializing...', name: 'WAWAPP_HOME');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    dev.log('Checking location permission...', name: 'WAWAPP_HOME');
    setState(() {
      _errorMessage = 'جاري تحديد موقعك...';
    });

    final hasPermission = await LocationService.checkPermissions();
    dev.log('Location permission result: $hasPermission', name: 'WAWAPP_HOME');

    if (hasPermission) {
      setState(() {
        _hasLocationPermission = true;
        _errorMessage = null;
      });
      await _getCurrentLocation();
    } else {
      setState(() {
        _errorMessage = null;
      });
      dev.log('Location permission denied, showing manual mode',
          name: 'WAWAPP_HOME');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يمكنك استخدام الخريطة يدوياً لتحديد المواقع'),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      await safeAnimateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
        action: 'current_location',
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('لم يتمكن من تحديد موقعك الحالي. يرجى التأكد من تفعيل GPS'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _onMapTap(LatLng location) async {
    await ref.read(routePickerProvider.notifier).setLocationFromTap(location);
    await safeAnimateCamera(
      CameraUpdate.newLatLng(location),
      action: 'map_tap',
    );
  }

  void _onCameraMove(CameraPosition position) {
    ref.read(currentZoomProvider.notifier).state = position.zoom;
  }

  void _showPlacesSheet(bool isPickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlacesAutocompleteSheet(
        isPickup: isPickup,
        onLocationSelected: () {
          // Update text controllers when location is selected
          final state = ref.read(routePickerProvider);
          _pickupController.text = state.pickupAddress;
          _dropoffController.text = state.dropoffAddress;
        },
      ),
    );
  }

  void _showSavedLocationsSheet(SavedLocationSelectionMode mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SavedLocationSelectorSheet(
        mode: mode,
        onLocationSelected: () {
          // Update text controllers when location is selected
          final state = ref.read(routePickerProvider);
          _pickupController.text = state.pickupAddress;
          _dropoffController.text = state.dropoffAddress;
        },
      ),
    );
  }

  Set<Marker> _buildMarkers(RoutePickerState state) {
    final markers = <Marker>{};

    if (state.pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: state.pickup!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'استلام', snippet: state.pickupAddress),
      ));
    }

    if (state.dropoff != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: state.dropoff!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'تسليم', snippet: state.dropoffAddress),
      ));
    }

    return markers;
  }

  void _fitBounds(RoutePickerState state) {
    final pickup = state.pickup;
    final dropoff = state.dropoff;

    if (pickup != null && dropoff != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          pickup.latitude < dropoff.latitude
              ? pickup.latitude
              : dropoff.latitude,
          pickup.longitude < dropoff.longitude
              ? pickup.longitude
              : dropoff.longitude,
        ),
        northeast: LatLng(
          pickup.latitude > dropoff.latitude
              ? pickup.latitude
              : dropoff.latitude,
          pickup.longitude > dropoff.longitude
              ? pickup.longitude
              : dropoff.longitude,
        ),
      );
      safeAnimateCamera(
        CameraUpdate.newLatLngBounds(bounds, 48.0),
        action: 'fit_bounds_both',
      );
    } else if (pickup != null) {
      safeAnimateCamera(
        CameraUpdate.newLatLngZoom(pickup, 15.0),
        action: 'fit_bounds_pickup',
      );
    }
  }

  void _handleCalculatePrice() {
    final routeState = ref.read(routePickerProvider);
    
    if (routeState.pickup == null || routeState.dropoff == null) {
      return;
    }

    final pickup = routeState.pickup!;
    final dropoff = routeState.dropoff!;

    final km = computeDistanceKm(
      lat1: pickup.latitude,
      lng1: pickup.longitude,
      lat2: dropoff.latitude,
      lng2: dropoff.longitude,
    );
    final breakdown = Pricing.compute(km);
    final price = breakdown.rounded;

    dev.log('Distance: ${km}km, Price: ${price}MRU', name: 'WAWAPP_LOC');

    ref.read(quoteProvider.notifier).setPickup(
        quote_latlng.LatLng(pickup.latitude, pickup.longitude));
    ref.read(quoteProvider.notifier).setDropoff(
        quote_latlng.LatLng(dropoff.latitude, dropoff.longitude));
    ref.read(quoteProvider.notifier).setDistance(km);
    ref.read(quoteProvider.notifier).setPrice(price.round());

    context.push('/quote');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final routeState = ref.watch(routePickerProvider);
    final selectedShipmentType = ref.watch(selectedShipmentTypeProvider);
    final theme = Theme.of(context);
    final shipmentColors = context.shipmentTypeColors;

    // Update text controllers when state changes (without triggering rebuilds)
    if (_pickupController.text != routeState.pickupAddress) {
      _pickupController.text = routeState.pickupAddress;
    }
    if (_dropoffController.text != routeState.dropoffAddress) {
      _dropoffController.text = routeState.dropoffAddress;
    }

    // Fit bounds ONCE when both locations are set and map is ready
    if (routeState.pickup != null &&
        routeState.dropoff != null &&
        isMapReady &&
        !_hasFittedBounds) {
      _hasFittedBounds = true;
      // Schedule this after the current frame to avoid triggering rebuild
      scheduleCameraOperation(() {
        _fitBounds(routeState);
      });
    }

    // Reset flag when locations change
    if (routeState.pickup == null || routeState.dropoff == null) {
      _hasFittedBounds = false;
    }

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(context, l10n),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Section
                _buildHeaderSection(context, l10n),
                
                SizedBox(height: WawAppSpacing.lg),
                
                // 2. Primary Action Card
                _buildPrimaryActionCard(
                  context, 
                  l10n, 
                  selectedShipmentType,
                  routeState,
                ),
                
                SizedBox(height: WawAppSpacing.lg),
                
                // 3. ShipmentType Quick Access
                _buildQuickCategorySelector(
                  context, 
                  l10n, 
                  selectedShipmentType,
                  shipmentColors,
                ),
                
                SizedBox(height: WawAppSpacing.lg),
                
                // 4. Current Shipment Status (placeholder)
                _buildCurrentShipmentCard(context, l10n),
                
                SizedBox(height: WawAppSpacing.lg),
                
                // 5. Past Shipments
                _buildPastShipmentsCard(context, l10n),
                
                SizedBox(height: WawAppSpacing.lg),
                
                // 6. Info Banner
                _buildInfoBanner(context, l10n),
                
                SizedBox(height: WawAppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return AppBar(
      title: Text(l10n.appTitle),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.language),
          onPressed: () {
            // Placeholder for future language switcher
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.language),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          tooltip: l10n.language,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                context.push('/profile');
                break;
              case 'about':
                context.push('/about');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person),
                  SizedBox(width: WawAppSpacing.xs),
                  Text(l10n.profile),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'about',
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  SizedBox(width: WawAppSpacing.xs),
                  Text(l10n.about_app),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.waving_hand,
              color: WawAppColors.secondary,
              size: 24,
            ),
            SizedBox(width: WawAppSpacing.xs),
            Text(
              l10n.greeting,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: WawAppSpacing.xxs),
        Text(
          l10n.welcome_back,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: WawAppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard(
    BuildContext context,
    AppLocalizations l10n,
    ShipmentType selectedType,
    RoutePickerState routeState,
  ) {
    final theme = Theme.of(context);
    final shipmentColors = context.shipmentTypeColors;
    
    // Get the color for the selected shipment type
    Color categoryColor;
    switch (selectedType) {
      case ShipmentType.foodAndPerishables:
        categoryColor = shipmentColors.foodPerishables;
        break;
      case ShipmentType.furnitureAndHomeSetup:
        categoryColor = shipmentColors.furniture;
        break;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        categoryColor = shipmentColors.construction;
        break;
      case ShipmentType.electricalAndHomeAppliances:
        categoryColor = shipmentColors.appliances;
        break;
      case ShipmentType.generalGoodsAndBoxes:
        categoryColor = shipmentColors.generalGoods;
        break;
      case ShipmentType.fragileOrSensitiveCargo:
        categoryColor = shipmentColors.fragile;
        break;
    }

    return WawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title and badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.start_new_shipment,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: WawAppSpacing.xxs),
                    Text(
                      l10n.select_pickup_dropoff,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WawAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: WawAppSpacing.sm),
              // Category badge
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: WawAppSpacing.sm,
                  vertical: WawAppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
                  border: Border.all(
                    color: categoryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedType.icon,
                      size: 16,
                      color: categoryColor,
                    ),
                    SizedBox(width: WawAppSpacing.xxs),
                    Text(
                      selectedType.arabicLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: WawAppSpacing.md),
          
          // Pickup location field
          TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              labelText: l10n.pickup,
              prefixIcon: IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () async {
                  await ref
                      .read(routePickerProvider.notifier)
                      .setCurrentLocation();
                },
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmark),
                    onPressed: () => _showSavedLocationsSheet(
                        SavedLocationSelectionMode.pickup),
                    tooltip: 'المواقع المحفوظة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: routeState.mapsEnabled
                        ? () => _showPlacesSheet(true)
                        : null,
                  ),
                ],
              ),
            ),
            readOnly: true,
            onTap: routeState.mapsEnabled ? () => _showPlacesSheet(true) : null,
          ),
          
          SizedBox(height: WawAppSpacing.sm),
          
          // Dropoff location field
          TextField(
            controller: _dropoffController,
            decoration: InputDecoration(
              labelText: l10n.dropoff,
              prefixIcon: const Icon(Icons.location_on),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmark),
                    onPressed: () => _showSavedLocationsSheet(
                        SavedLocationSelectionMode.dropoff),
                    tooltip: 'المواقع المحفوظة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: routeState.mapsEnabled
                        ? () => _showPlacesSheet(false)
                        : null,
                  ),
                ],
              ),
            ),
            readOnly: true,
            onTap: routeState.mapsEnabled ? () => _showPlacesSheet(false) : null,
          ),
          
          SizedBox(height: WawAppSpacing.md),
          
          // Map Section
          if (routeState.mapsEnabled) ...[
            // Selection Mode Toggle
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: WawAppSpacing.md,
                vertical: WawAppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    routeState.selectingPickup ? Icons.my_location : Icons.location_on,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: WawAppSpacing.xs),
                  Expanded(
                    child: Text(
                      routeState.selectingPickup
                          ? 'اضغط على الخريطة لتحديد موقع الاستلام'
                          : 'اضغط على الخريطة لتحديد موقع التسليم',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(routePickerProvider.notifier).toggleSelection();
                    },
                    icon: Icon(
                      Icons.swap_vert,
                      size: 18,
                    ),
                    label: Text(
                      routeState.selectingPickup ? 'تسليم' : 'استلام',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: WawAppSpacing.sm,
                        vertical: WawAppSpacing.xxs,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: WawAppSpacing.sm),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
                border: Border.all(
                  color: WawAppColors.borderLight,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: Consumer(
                builder: (context, ref, child) {
                  final polygons = ref.watch(districtPolygonsProvider);
                  final locale = Localizations.localeOf(context);
                  final markersAsync =
                      ref.watch(districtMarkersProvider(locale.languageCode));

                  return markersAsync.when(
                    data: (districtMarkers) => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        onMapCreated(controller);
                        dev.log('Map controller initialized', name: 'WAWAPP_HOME');
                        // Fit bounds will be handled by the build logic when ready
                      },
                      onCameraMove: _onCameraMove,
                      onTap: _onMapTap,
                      initialCameraPosition: routeState.pickup != null
                          ? CameraPosition(
                              target: routeState.pickup!,
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      markers: {
                        ..._buildMarkers(routeState),
                        ...districtMarkers
                      },
                      polygons: polygons,
                      myLocationEnabled: _hasLocationPermission,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => GoogleMap(
                      onMapCreated: onMapCreated,
                      onCameraMove: _onCameraMove,
                      onTap: _onMapTap,
                      initialCameraPosition: _nouakchott,
                      markers: _buildMarkers(routeState),
                      myLocationEnabled: _hasLocationPermission,
                      myLocationButtonEnabled: true,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: WawAppSpacing.xs),
            Text(
              'اضغط على الخريطة لتحديد الموقع',
              style: theme.textTheme.bodySmall?.copyWith(
                color: WawAppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          SizedBox(height: WawAppSpacing.md),
          
          // Action button
          WawActionButton(
            label: l10n.begin_shipment,
            icon: Icons.arrow_forward,
            onPressed: (routeState.pickup != null && routeState.dropoff != null)
                ? _handleCalculatePrice
                : null,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategorySelector(
    BuildContext context,
    AppLocalizations l10n,
    ShipmentType selectedType,
    ShipmentTypeColors shipmentColors,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quick_select_category,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: WawAppSpacing.sm),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ShipmentType.values.map((type) {
              Color categoryColor;
              switch (type) {
                case ShipmentType.foodAndPerishables:
                  categoryColor = shipmentColors.foodPerishables;
                  break;
                case ShipmentType.furnitureAndHomeSetup:
                  categoryColor = shipmentColors.furniture;
                  break;
                case ShipmentType.constructionMaterialsAndHeavyLoad:
                  categoryColor = shipmentColors.construction;
                  break;
                case ShipmentType.electricalAndHomeAppliances:
                  categoryColor = shipmentColors.appliances;
                  break;
                case ShipmentType.generalGoodsAndBoxes:
                  categoryColor = shipmentColors.generalGoods;
                  break;
                case ShipmentType.fragileOrSensitiveCargo:
                  categoryColor = shipmentColors.fragile;
                  break;
              }
              
              final isSelected = type == selectedType;
              
              return Padding(
                padding: EdgeInsetsDirectional.only(
                  end: WawAppSpacing.sm,
                ),
                child: InkWell(
                  onTap: () {
                    context.push('/shipment-type');
                  },
                  borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? categoryColor.withOpacity(0.1)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? categoryColor
                            : WawAppColors.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          size: 28,
                          color: isSelected
                              ? categoryColor
                              : WawAppColors.textSecondaryLight,
                        ),
                        SizedBox(height: WawAppSpacing.xxs),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentShipmentCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    // Placeholder: No active shipment
    return WawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: WawAppSpacing.xs),
              Text(
                l10n.current_shipment,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: WawAppSpacing.sm),
          Center(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: WawAppSpacing.sm,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: WawAppColors.textSecondaryLight,
                  ),
                  SizedBox(height: WawAppSpacing.xs),
                  Text(
                    l10n.no_active_shipments,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: WawAppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastShipmentsCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return WawCard(
      child: InkWell(
        onTap: () {
          // Navigate to order history (placeholder)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.view_history),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
        child: Padding(
          padding: EdgeInsetsDirectional.all(WawAppSpacing.xs),
          child: Row(
            children: [
              Container(
                padding: EdgeInsetsDirectional.all(WawAppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.history,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: WawAppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.past_shipments,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.view_history,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: WawAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: WawAppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          SizedBox(width: WawAppSpacing.sm),
          Expanded(
            child: Text(
              l10n.safe_reliable_delivery,
              style: theme.textTheme.bodySmall?.copyWith(
                color: WawAppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
