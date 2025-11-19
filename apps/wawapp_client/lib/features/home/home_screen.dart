import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../map/pick_route_controller.dart';
import '../map/places_autocomplete_sheet.dart';
import '../quote/providers/quote_provider.dart';
import '../quote/models/latlng.dart' as quote_latlng;
import '../../core/geo/distance.dart';
import '../../core/pricing/pricing.dart';
import '../../core/location/location_service.dart';
import '../map/providers/district_layer_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  static const CameraPosition _nouakchott = CameraPosition(
    target: LatLng(18.0735, -15.9582),
    zoom: 14.0,
  );
  bool _hasLocationPermission = false;
  String? _errorMessage;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

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
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
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
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
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
    if (_mapController == null) return;

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
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48.0));
    } else if (pickup != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final routeState = ref.watch(routePickerProvider);

    // Update text controllers when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pickupController.text != routeState.pickupAddress) {
        _pickupController.text = routeState.pickupAddress;
      }
      if (_dropoffController.text != routeState.dropoffAddress) {
        _dropoffController.text = routeState.dropoffAddress;
      }
      // Fit bounds when both locations are set
      if (routeState.pickup != null && routeState.dropoff != null) {
        _fitBounds(routeState);
      }
    });

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(l10n.appTitle),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.push('/about'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 300,
                        child: _errorMessage != null
                            ? Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_errorMessage ==
                                          'جاري تحديد موقعك...')
                                        const CircularProgressIndicator()
                                      else
                                        const Icon(Icons.location_off,
                                            size: 64, color: Colors.grey),
                                      const SizedBox(height: 16),
                                      Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : !routeState.mapsEnabled
                                ? Container(
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined,
                                              size: 64, color: Colors.grey),
                                          SizedBox(height: 16),
                                          Text(
                                            'الخريطة غير متوفرة في هذا الإصدار\nيمكنك استخدام النقر لتحديد المواقع يدوياً',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Consumer(
                                    builder: (context, ref, child) {
                                      final polygons = ref.watch(districtPolygonsProvider);
                                      final locale = Localizations.localeOf(context);
                                      final markersAsync = ref.watch(districtMarkersProvider(locale.languageCode));
                                      
                                      return markersAsync.when(
                                        data: (districtMarkers) => GoogleMap(
                                          onMapCreated: (GoogleMapController controller) {
                                            dev.log('GoogleMap created successfully', name: 'WAWAPP_HOME');
                                            _mapController = controller;
                                            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(routeState));
                                          },
                                          initialCameraPosition: _nouakchott,
                                          myLocationEnabled: _hasLocationPermission,
                                          myLocationButtonEnabled: _hasLocationPermission,
                                          onTap: _onMapTap,
                                          onCameraMove: _onCameraMove,
                                          markers: {..._buildMarkers(routeState), ...districtMarkers},
                                          polygons: polygons,
                                          compassEnabled: true,
                                          mapToolbarEnabled: false,
                                          zoomControlsEnabled: true,
                                        ),
                                        loading: () => GoogleMap(
                                          onMapCreated: (GoogleMapController controller) {
                                            dev.log('GoogleMap created successfully', name: 'WAWAPP_HOME');
                                            _mapController = controller;
                                            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(routeState));
                                          },
                                          initialCameraPosition: _nouakchott,
                                          myLocationEnabled: _hasLocationPermission,
                                          myLocationButtonEnabled: _hasLocationPermission,
                                          onTap: _onMapTap,
                                          onCameraMove: _onCameraMove,
                                          markers: _buildMarkers(routeState),
                                          polygons: polygons,
                                          compassEnabled: true,
                                          mapToolbarEnabled: false,
                                          zoomControlsEnabled: true,
                                        ),
                                        error: (error, stack) => GoogleMap(
                                          onMapCreated: (GoogleMapController controller) {
                                            dev.log('GoogleMap created successfully', name: 'WAWAPP_HOME');
                                            _mapController = controller;
                                            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(routeState));
                                          },
                                          initialCameraPosition: _nouakchott,
                                          myLocationEnabled: _hasLocationPermission,
                                          myLocationButtonEnabled: _hasLocationPermission,
                                          onTap: _onMapTap,
                                          onCameraMove: _onCameraMove,
                                          markers: _buildMarkers(routeState),
                                          polygons: polygons,
                                          compassEnabled: true,
                                          mapToolbarEnabled: false,
                                          zoomControlsEnabled: true,
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      if (_errorMessage == null)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4)
                              ],
                            ),
                            child: ChoiceChip(
                              label: Text(
                                routeState.selectingPickup
                                    ? 'اختر موقع الاستلام'
                                    : 'اختر موقع التسليم',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: true,
                              onSelected: (_) => ref
                                  .read(routePickerProvider.notifier)
                                  .toggleSelection(),
                              selectedColor: routeState.selectingPickup
                                  ? Colors.green[100]
                                  : Colors.red[100],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: routeState.mapsEnabled
                            ? () => _showPlacesSheet(true)
                            : null,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: routeState.mapsEnabled
                        ? () => _showPlacesSheet(true)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dropoffController,
                    decoration: InputDecoration(
                      labelText: l10n.dropoff,
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: routeState.mapsEnabled
                            ? () => _showPlacesSheet(false)
                            : null,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: routeState.mapsEnabled
                        ? () => _showPlacesSheet(false)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (routeState.pickup != null &&
                              routeState.dropoff != null)
                          ? () {
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

                              dev.log('Distance: ${km}km, Price: ${price}MRU',
                                  name: 'WAWAPP_LOC');

                              ref.read(quoteProvider.notifier).setPickup(
                                  quote_latlng.LatLng(
                                      pickup.latitude, pickup.longitude));
                              ref.read(quoteProvider.notifier).setDropoff(
                                  quote_latlng.LatLng(
                                      dropoff.latitude, dropoff.longitude));
                              ref.read(quoteProvider.notifier).setDistance(km);
                              ref
                                  .read(quoteProvider.notifier)
                                  .setPrice(price.round());

                              context.push('/quote');
                            }
                          : null,
                      child: const Text('احسب السعر'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
