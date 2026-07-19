// lib/views/widgets/menu_picker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_network_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MENU PICKER  (formulaires admin)
// ─────────────────────────────────────────────────────────────────────────────

class MenuPicker extends StatefulWidget {
  final String? initialMenuUrl;
  final String? initialMenuType;
  final Function(String? menuUrl, String? menuType) onMenuChanged;

  const MenuPicker({
    super.key,
    this.initialMenuUrl,
    this.initialMenuType,
    required this.onMenuChanged,
  });

  @override
  State<MenuPicker> createState() => MenuPickerState();
}

class MenuPickerState extends State<MenuPicker> {
  String _menuType = 'none';
  final TextEditingController _linkController = TextEditingController();
  File? _selectedFile;
  String? _existingMenuUrl;

  File? get selectedFile => _selectedFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialMenuUrl != null && widget.initialMenuUrl!.isNotEmpty) {
      _existingMenuUrl = widget.initialMenuUrl;
      _menuType = widget.initialMenuType ?? 'link';
      if (_menuType == 'link') _linkController.text = widget.initialMenuUrl!;
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    switch (_menuType) {
      case 'none':
        widget.onMenuChanged(null, null);
        break;
      case 'link':
        widget.onMenuChanged(
          _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
          'link',
        );
        break;
      case 'file':
        if (_selectedFile != null) {
          widget.onMenuChanged(_selectedFile!.path, 'file');
        } else if (_existingMenuUrl != null) {
          widget.onMenuChanged(_existingMenuUrl, 'file');
        }
        break;
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _selectedFile = File(result.files.single.path!));
        _notifyChange();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        color: theme.brightness == Brightness.light ? Colors.grey.shade50 : theme.cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Menu (optionnel)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'none',  label: Text('Aucun'),   icon: Icon(Icons.block, size: 16)),
              ButtonSegment(value: 'link',  label: Text('Lien'),    icon: Icon(Icons.link,  size: 16)),
              ButtonSegment(value: 'file',  label: Text('Fichier'), icon: Icon(Icons.upload_file, size: 16)),
            ],
            selected: {_menuType},
            onSelectionChanged: (v) {
              setState(() {
                _menuType = v.first;
                if (_menuType == 'none') {
                  _linkController.clear();
                  _selectedFile = null;
                  _existingMenuUrl = null;
                }
              });
              _notifyChange();
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              selectedForegroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // ── Lien ──────────────────────────────────────────
          if (_menuType == 'link') ...[
            TextFormField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'URL du menu',
                hintText: 'https://exemple.com/menu.pdf',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) => _notifyChange(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.startsWith('http://') && !v.startsWith('https://')) {
                  return 'URL invalide (doit commencer par http:// ou https://)';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            if (_linkController.text.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.tryParse(_linkController.text);
                  if (url != null && await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Prévisualiser'),
              ),
          ],

          // ── Fichier ────────────────────────────────────────
          if (_menuType == 'file') ...[
            if (_existingMenuUrl != null && _selectedFile == null) ...[
              _FileStatusTile(
                icon: Icons.check_circle,
                iconColor: Colors.green,
                label: 'Menu déjà enregistré',
                trailing: TextButton(
                  onPressed: () { setState(() => _existingMenuUrl = null); _notifyChange(); },
                  child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_selectedFile != null) ...[
              _FileStatusTile(
                icon: Icons.insert_drive_file,
                iconColor: theme.colorScheme.primary,
                label: _selectedFile!.path.split('/').last,
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () { setState(() => _selectedFile = null); _notifyChange(); },
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_selectedFile == null && _existingMenuUrl == null
                  ? 'Choisir un fichier'
                  : 'Changer le fichier'),
            ),
            const SizedBox(height: 6),
            Text('Formats acceptés : PDF, JPG, PNG',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ],
        ],
      ),
    );
  }
}

class _FileStatusTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;

  const _FileStatusTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU VIEWER  (detail_screen – côté utilisateur)
// ─────────────────────────────────────────────────────────────────────────────

class MenuViewer extends StatelessWidget {
  final String menuUrl;
  final String? menuType;

  const MenuViewer({super.key, required this.menuUrl, this.menuType});

  bool get _isPdf =>
      menuUrl.toLowerCase().contains('.pdf') || menuUrl.toLowerCase().contains('%2Fpdf');

  bool get _isImage =>
      menuUrl.toLowerCase().contains('.jpg') ||
          menuUrl.toLowerCase().contains('.jpeg') ||
          menuUrl.toLowerCase().contains('.png') ||
          menuUrl.toLowerCase().contains('.webp');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: Icon(
        _isPdf ? Icons.picture_as_pdf_outlined : Icons.restaurant_menu_outlined,
        color: theme.colorScheme.primary,
      ),
      label: const Text('Voir le menu'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    // Lien externe → navigateur in-app
    if (menuType == 'link') {
      final uri = Uri.tryParse(menuUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      return;
    }

    // Fichier uploadé (URL Firebase Storage)
    if (_isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewerScreen(url: menuUrl)),
      );
    } else {
      // PDF ou autre → navigateur in-app (évite la dépendance flutter_pdfview)
      final uri = Uri.tryParse(menuUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Viewer in-app
// ─────────────────────────────────────────────────────────────────────────────

class _ImageViewerScreen extends StatelessWidget {
  final String url;
  const _ImageViewerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Menu'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: AppNetworkImage(
            url: url,
            fit: BoxFit.contain,
            fallbackIcon: Icons.broken_image_outlined,
          ),
        ),
      ),
    );
  }
}