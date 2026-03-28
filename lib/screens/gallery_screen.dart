import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Map<String, List<File>> _folderImages = {};
  bool _loading = true;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/images');
    final Map<String, List<File>> result = {};
    if (await base.exists()) {
      await for (final entity in base.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split('/').last;
          final files = await entity
              .list()
              .where((e) => e.path.endsWith('.png'))
              .map((e) => File(e.path))
              .toList();
          files.sort((a, b) => a.path.compareTo(b.path));
          if (files.isNotEmpty) result[folderName] = files;
        }
      }
    }
    if (mounted) {
      setState(() {
        _folderImages = result;
        _loading = false;
      });
    }
  }

  Future<void> _deleteImage(String folder, File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete image?'),
        content: Text('Delete ${file.path.split('/').last} from $folder?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await file.delete();
      _loadImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_folderImages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery')),
        body: const Center(child: Text('No images collected yet.')),
      );
    }

    final folders = _folderImages.keys.toList()..sort();

    if (_selectedFolder != null &&
        _folderImages.containsKey(_selectedFolder)) {
      final images = _folderImages[_selectedFolder]!;
      return Scaffold(
        appBar: AppBar(
          title: Text(_selectedFolder!),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedFolder = null),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: images.length,
          itemBuilder: (ctx, i) {
            final file = images[i];
            return GestureDetector(
              onLongPress: () => _deleteImage(_selectedFolder!, file),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        'img$i',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (ctx, i) {
          final folder = folders[i];
          final images = _folderImages[folder]!;
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(images.first,
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
            title: Text(folder),
            subtitle: Text('${images.length} image(s)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _selectedFolder = folder),
          );
        },
      ),
    );
  }
}
