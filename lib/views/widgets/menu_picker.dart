// lib/widgets/menu_picker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class MenuPicker extends StatefulWidget {
  final String? initialMenuUrl;
  final String? initialMenuType; // 'link' or 'file'
  final Function(String? menuUrl, String? menuType) onMenuChanged;

  const MenuPicker({
    super.key,
    this.initialMenuUrl,
    this.initialMenuType,
    required this.onMenuChanged,
  });

  @override
  State<MenuPicker> createState() => _MenuPickerState();
}

class _MenuPickerState extends State<MenuPicker> {
  String _menuType = 'none'; // 'none', 'link', 'file'
  final TextEditingController _linkController = TextEditingController();
  File? _selectedFile;
  String? _existingMenuUrl;

  @override
  void initState() {
    super.initState();

    if (widget.initialMenuUrl != null && widget.initialMenuUrl!.isNotEmpty) {
      _existingMenuUrl = widget.initialMenuUrl;
      _menuType = widget.initialMenuType ?? 'link';

      if (_menuType == 'link') {
        _linkController.text = widget.initialMenuUrl!;
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    if (_menuType == 'none') {
      widget.onMenuChanged(null, null);
    } else if (_menuType == 'link') {
      widget.onMenuChanged(_linkController.text.trim(), 'link');
    } else if (_menuType == 'file' && _selectedFile != null) {
      widget.onMenuChanged(_selectedFile!.path, 'file');
    } else if (_menuType == 'file' && _existingMenuUrl != null) {
      widget.onMenuChanged(_existingMenuUrl, 'file');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _notifyChange();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📄 Menu (optionnel)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Type de menu
            DropdownButtonFormField<String>(
              value: _menuType,
              decoration: const InputDecoration(
                labelText: 'Type de menu',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Aucun')),
                DropdownMenuItem(value: 'link', child: Text('Lien URL')),
                DropdownMenuItem(value: 'file', child: Text('Fichier (PDF/Image)')),
              ],
              onChanged: (value) {
                setState(() {
                  _menuType = value ?? 'none';
                  if (_menuType == 'none') {
                    _linkController.clear();
                    _selectedFile = null;
                    _existingMenuUrl = null;
                  }
                  _notifyChange();
                });
              },
            ),

            const SizedBox(height: 16),

            // Champ lien
            if (_menuType == 'link') ...[
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'URL du menu',
                  hintText: 'https://exemple.com/menu.pdf',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _notifyChange(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // Optionnel
                  }
                  if (!value.startsWith('http://') && !value.startsWith('https://')) {
                    return 'URL invalide (doit commencer par http:// ou https://)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (_linkController.text.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(_linkController.text);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Prévisualiser'),
                ),
            ],

            // Sélection fichier
            if (_menuType == 'file') ...[
              if (_existingMenuUrl != null && _selectedFile == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Menu déjà téléchargé',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _existingMenuUrl = null;
                            _notifyChange();
                          });
                        },
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (_selectedFile != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFile!.path.split('/').last,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                            _notifyChange();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_selectedFile == null && _existingMenuUrl == null
                    ? 'Sélectionner un fichier'
                    : 'Changer le fichier'),
              ),
              const SizedBox(height: 8),
              Text(
                'Formats acceptés: PDF, JPG, PNG',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Helper pour obtenir le fichier sélectionné
extension MenuPickerHelper on MenuPicker {
  File? getSelectedFile() {
    final state = (key as GlobalKey<_MenuPickerState>?)?.currentState;
    return state?._selectedFile;
  }
}