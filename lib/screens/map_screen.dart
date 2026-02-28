import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import '../widgets/entry_widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  late final EntriesNotifier _notifier;
  late final VoidCallback _listener;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _notifier = EntriesNotifier();
    _listener = () => _loadMarkers();
    _notifier.addListener(_listener);
    _loadMarkers();
  }

  @override
  void dispose() {
    _notifier.removeListener(_listener);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkers() async {
    final entries = await DatabaseHelper().getEntries();
    final Set<Marker> newMarkers = {};

    for (var entry in entries) {
      if (entry.location != null) {
        // Since we only have location names, we'd normally geocode them.
        // For this implementation, if we don't have lat/lng stored, 
        // we'll assume most recent entries for the demo.
        // In a real app, we should store LatLng in the DB.
        // TODO: Update PhotoEntry to include latitude/longitude
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Memory Map"), centerTitle: true),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            style: _mapStyle,
          ),
    );
  }

  final String _mapStyle = ""; // Custom dark/light style logic would go here
}
