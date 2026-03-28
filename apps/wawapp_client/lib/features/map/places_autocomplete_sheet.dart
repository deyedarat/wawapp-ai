import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_place/google_place.dart';
import 'pick_route_controller.dart';

class PlacesAutocompleteSheet extends ConsumerStatefulWidget {
  final bool isPickup;
  final VoidCallback onLocationSelected;

  const PlacesAutocompleteSheet({
    super.key,
    required this.isPickup,
    required this.onLocationSelected,
  });

  @override
  ConsumerState<PlacesAutocompleteSheet> createState() =>
      _PlacesAutocompleteSheetState();
}

class _PlacesAutocompleteSheetState
    extends ConsumerState<PlacesAutocompleteSheet> {
  final TextEditingController _controller = TextEditingController();
  List<AutocompletePrediction> _predictions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final predictions =
        await ref.read(routePickerProvider.notifier).searchPlaces(query);

    if (mounted) {
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    }
  }

  void _onPlaceSelected(AutocompletePrediction prediction) async {
    if (prediction.placeId == null) return;

    setState(() {
      _isLoading = true;
    });

    final details = await ref
        .read(routePickerProvider.notifier)
        .getPlaceDetails(prediction.placeId!);

    if (details != null && mounted) {
      await ref
          .read(routePickerProvider.notifier)
          .setLocationFromPlace(details, widget.isPickup);
      widget.onLocationSelected();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routePickerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            widget.isPickup ? 'اختر موقع الاستلام' : 'اختر موقع التسليم',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (!routeState.mapsEnabled)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'البحث عن الأماكن غير متوفر في هذا الإصدار. يمكنك النقر على الخريطة لتحديد الموقع.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          if (routeState.mapsEnabled)
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'ابحث عن موقع...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
              autofocus: true,
            ),
          if (routeState.mapsEnabled) const SizedBox(height: 16),
          if (routeState.mapsEnabled && _isLoading)
            const Center(child: CircularProgressIndicator()),
          if (routeState.mapsEnabled && !_isLoading)
            Expanded(
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(prediction.description ?? ''),
                    onTap: () => _onPlaceSelected(prediction),
                  );
                },
              ),
            ),
          if (!routeState.mapsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ),
        ],
      ),
    );
  }
}
