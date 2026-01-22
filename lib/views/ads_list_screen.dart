import 'package:flutter/material.dart';

//import '../models/ad_model.dart';
import 'package:kin_experience/models/ad_model.dart';
import 'package:kin_experience/services/ad_service.dart';

import 'add_ad_form.dart';
import 'edit_ad_form.dart';

/// Admin screen: list all ads with actions (edit / delete / toggle).
class AdsListScreen extends StatelessWidget {
  const AdsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ads = AdsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des publicités'),
        actions: [
          IconButton(
            tooltip: 'Ajouter',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddAdForm()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AdModel>>(
        stream: ads.watchAllAds(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Aucune publicité.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final ad = items[i];
              return _AdTile(ad: ad, ads: ads);
            },
          );
        },
      ),
    );
  }
}

class _AdTile extends StatelessWidget {
  final AdModel ad;
  final AdsService ads;

  const _AdTile({required this.ad, required this.ads});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final img = ad.image;
    final isNetwork = img.startsWith('http://') || img.startsWith('https://');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 92,
                height: 62,
                child: isNetwork
                    ? Image.network(img, fit: BoxFit.cover)
                    : Image.asset(img, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        ad.isActive ? Icons.check_circle : Icons.remove_circle_outline,
                        size: 16,
                        color: ad.isActive ? Colors.green : theme.disabledColor,
                      ),
                      const SizedBox(width: 6),
                      Text(ad.isActive ? 'Active' : 'Inactive', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EditAdForm(ad: ad)),
                    );
                  },
                ),
                IconButton(
                  tooltip: ad.isActive ? 'Désactiver' : 'Activer',
                  icon: Icon(ad.isActive ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => ads.toggleAd(adId: ad.id, isActive: !ad.isActive),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer la pub ?'),
                        content: const Text('Cette action est irréversible.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      await ads.deleteAd(ad.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
