import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_photo_cache.dart';
import '../sarisupply_design_system.dart';

class ProductImagePreset {
  const ProductImagePreset({
    required this.name,
    required this.emoji,
    required this.url,
  });

  final String name;
  final String emoji;
  final String url;
}

class ProductImagePresets {
  static const List<ProductImagePreset> all = [
    ProductImagePreset(
      name: 'Canned Goods',
      emoji: '🥫',
      url:
          'https://images.unsplash.com/photo-1584947920387-9bc683bc4892?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Beverages',
      emoji: '🥤',
      url:
          'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Snacks & Chips',
      emoji: '🍿',
      url:
          'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Instant Noodles',
      emoji: '🍜',
      url:
          'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Coffee & Milk',
      emoji: '☕',
      url:
          'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Rice & Grains',
      emoji: '🍚',
      url:
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Personal Care',
      emoji: '🧼',
      url:
          'https://images.unsplash.com/photo-1607006314644-8c8861d8c1c4?auto=format&fit=crop&w=400&q=80',
    ),
    ProductImagePreset(
      name: 'Condiments & Oil',
      emoji: '🧂',
      url:
          'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80',
    ),
  ];

  /// Guess a good preset image URL based on product name or SKU.
  static String? suggestForProduct(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('beef') ||
        lower.contains('sardine') ||
        lower.contains('tuna') ||
        lower.contains('can') ||
        lower.contains('meat')) {
      return all[0].url;
    } else if (lower.contains('coke') ||
        lower.contains('cola') ||
        lower.contains('soda') ||
        lower.contains('sprite') ||
        lower.contains('juice') ||
        lower.contains('water') ||
        lower.contains('drink') ||
        lower.contains('tea')) {
      return all[1].url;
    } else if (lower.contains('chip') ||
        lower.contains('biscuit') ||
        lower.contains('cracker') ||
        lower.contains('snack') ||
        lower.contains('candy')) {
      return all[2].url;
    } else if (lower.contains('noodle') ||
        lower.contains('pancit') ||
        lower.contains('ramen')) {
      return all[3].url;
    } else if (lower.contains('coffee') ||
        lower.contains('milk') ||
        lower.contains('sugar')) {
      return all[4].url;
    } else if (lower.contains('rice') || lower.contains('bigas')) {
      return all[5].url;
    } else if (lower.contains('soap') ||
        lower.contains('shampoo') ||
        lower.contains('detergent')) {
      return all[6].url;
    } else if (lower.contains('oil') ||
        lower.contains('sauce') ||
        lower.contains('vinegar') ||
        lower.contains('salt')) {
      return all[7].url;
    }
    return null;
  }
}

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    this.imageUrl,
    required this.productName,
    this.size = 52.0,
    this.borderRadius = 8.0,
  });

  final String? imageUrl;
  final String productName;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl!.trim()
        : ProductImagePresets.suggestForProduct(productName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SariSupplyColors.ink50,
        borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
        border: Border.all(color: SariSupplyColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SariSupplyRadii.sm - 1),
        child: effectiveUrl != null && effectiveUrl.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: effectiveUrl,
                cacheManager: ProductPhotoCache.instance,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Center(
                    child: SizedBox(
                      width: size * 0.4,
                      height: size * 0.4,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorWidget: (context, url, error) => _buildFallbackIcon(),
              )
            : _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    final lower = productName.toLowerCase();
    final (icon, color) = _getCategoryVisuals(lower);

    return Container(
      color: color.withValues(alpha: 0.12),
      child: Center(
        child: Icon(icon, size: size * 0.5, color: color),
      ),
    );
  }

  (IconData, Color) _getCategoryVisuals(String lower) {
    if (lower.contains('beef') ||
        lower.contains('sardine') ||
        lower.contains('can')) {
      return (Icons.inventory_2, SariSupplyColors.error);
    } else if (lower.contains('coke') ||
        lower.contains('drink') ||
        lower.contains('water') ||
        lower.contains('tea')) {
      return (Icons.local_drink, SariSupplyColors.info);
    } else if (lower.contains('chip') ||
        lower.contains('snack') ||
        lower.contains('biscuit')) {
      return (Icons.cookie, SariSupplyColors.warning);
    } else if (lower.contains('noodle') || lower.contains('pancit')) {
      return (Icons.ramen_dining, SariSupplyColors.orange500);
    } else if (lower.contains('coffee') || lower.contains('milk')) {
      return (Icons.coffee, SariSupplyColors.ink600);
    } else if (lower.contains('rice') || lower.contains('grain')) {
      return (Icons.grain, SariSupplyColors.success);
    } else if (lower.contains('soap') || lower.contains('clean')) {
      return (Icons.clean_hands, SariSupplyColors.ink300);
    }
    return (Icons.shopping_bag, SariSupplyColors.ink800);
  }
}
