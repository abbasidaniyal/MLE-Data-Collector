import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_screen.dart';
import 'gallery_screen.dart';
import '../utils/zip_exporter.dart';

const List<String> kClasses = [
  'pen', 'paper', 'book', 'clock', 'phone', 'laptop',
  'chair', 'desk', 'bottle', 'keychain', 'backpack', 'calculator',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _selectedClasses = {};
  Map<String, int> _imageCounts = {};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final dir = await getApplicationDocumentsDirectory();
    final Map<String, int> counts = {};
    final base = Directory('${dir.path}/images');
    if (await base.exists()) {
      await for (final entity in base.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split('/').last;
          final files = await entity
              .list()
              .where((e) => e.path.endsWith('.png'))
              .length;
          counts[folderName] = files;
        }
      }
    }
    if (mounted) setState(() => _imageCounts = counts);
  }

  void _toggleClass(String cls) {
    setState(() {
      if (_selectedClasses.contains(cls)) {
        _selectedClasses.remove(cls);
      } else {
        _selectedClasses.add(cls);
      }
    });
  }

  Future<void> _openCamera() async {
    if (_selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one class first')),
      );
      return;
    }
    final sortedClasses = List<String>.from(_selectedClasses)..sort();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(selectedClasses: sortedClasses),
      ),
    );
    _refreshCounts();
  }

  Future<void> _exportZip() async {
    setState(() => _exporting = true);
    try {
      final zipPath = await ZipExporter.exportZip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ZIP exported to:\n$zipPath'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  int get _totalImages => _imageCounts.values.fold(0, (sum, c) => sum + c);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedSelected = List<String>.from(_selectedClasses)..sort();
    final folderPreview =
        sortedSelected.isEmpty ? '(none selected)' : sortedSelected.join('_');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('ML Data Collector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Gallery',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              );
              _refreshCounts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive),
            tooltip: 'Export ZIP',
            onPressed: _exporting ? null : _exportZip,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total images: $_totalImages',
                    style: theme.textTheme.titleMedium),
                Text('${_selectedClasses.length} selected',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select classes for next photo:',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kClasses.map((cls) {
                      final selected = _selectedClasses.contains(cls);
                      final count = _imageCounts[cls] ?? 0;
                      return FilterChip(
                        label: Text('$cls\n${count}px'),
                        selected: selected,
                        onSelected: (_) => _toggleClass(cls),
                        backgroundColor: count > 0
                            ? theme.colorScheme.secondaryContainer
                            : null,
                        checkmarkColor: theme.colorScheme.onPrimary,
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: selected ? theme.colorScheme.onPrimary : null,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saves to: $folderPreview/',
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_imageCounts.isNotEmpty) ...[
                    Text(
                      'Collected images:',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: (_imageCounts.entries.toList()
                              ..sort((a, b) => a.key.compareTo(b.key)))
                            .map((e) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.folder_open,
                                      size: 20),
                                  title: Text(e.key),
                                  trailing: Chip(
                                    label: Text('${e.value} imgs'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Take Photo'),
      ),
    );
  }
}
