import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Notification",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          _sectionTitle(context, "Today"),
          const SizedBox(height: 10),

          _notificationTile(
            context,
            imageUrl:
            "https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=200&q=60",
            title: "Next booking on April 27",
            date: "7 Feb 2023 • 7:40 pm",
            description:
            "You have a booking to Padma Parking Centre on April 27, 2024.",
          ),

          const SizedBox(height: 14),

          _notificationTile(
            context,
            imageUrl:
            "https://images.unsplash.com/photo-1596558450255-7c0b7be9d56a?auto=format&fit=crop&w=200&q=60",
            title: "Get 20% Discount",
            date: "7 Feb 2023 • 7:40 pm",
            description:
            "Complete 20 bookings and get 20% discount on your next parking!",
            titleColor: Colors.green,
          ),

          const SizedBox(height: 22),

          _sectionTitle(context, "This Week"),
          const SizedBox(height: 10),

          _notificationTile(
            context,
            imageUrl:
            "https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?auto=format&fit=crop&w=200&q=60",
            title: "Booking successful",
            date: "6 Feb 2023 • 7:40 pm",
            description: "Your booking to DNS parking zone was successful.",
          ),

          const SizedBox(height: 14),

          _notificationTile(
            context,
            imageUrl:
            "https://images.unsplash.com/photo-1542362567-b07e54358753?auto=format&fit=crop&w=200&q=60",
            title: "Booking Cancelled",
            date: "2 Feb 2023 • 7:40 pm",
            description:
            "Your booking to Navana parking zone cancelled successfully.",
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.65),
      ),
    );
  }

  Widget _notificationTile(
      BuildContext context, {
        required String imageUrl,
        required String title,
        required String date,
        required String description,
        Color? titleColor,
      }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            imageUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 52,
              height: 52,
              color: theme.dividerColor.withOpacity(0.15),
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: titleColor ?? theme.textTheme.titleSmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.25,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
