// Le carrousel est implémenté avec un PageView plutôt que la
// dépendance `carousel_slider`, afin d’éviter les conflits de nom avec
// le type CarouselController introduit dans Flutter 3.13+.
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../localization/app_localizations.dart';
import '../../views/widgets/place_card.dart';

/// Carrousel horizontal mettant en avant les lieux « Mis en avant ».
/// Utilise la librairie [carousel_slider] pour un défilement fluide.
class FeaturedCarousel extends StatefulWidget {
  final List<dynamic> featuredPlaces;
  final Function(dynamic) onTap;

  const FeaturedCarousel({
    Key? key,
    required this.featuredPlaces,
    required this.onTap,
  }) : super(key: key);

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  // Contrôleur de page pour gérer le défilement.  Le viewportFraction
  // permet d’afficher plusieurs cartes et de laisser entrevoir la suivante.
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            loc.translate('featured_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.featuredPlaces.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final place = widget.featuredPlaces[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: PlaceCard(
                  place: place,
                  onTap: () => widget.onTap(place),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.featuredPlaces.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? Constants.primaryColor
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}