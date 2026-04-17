import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/charger_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MyChargersScreen extends ConsumerWidget {
  const MyChargersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargersAsyncValue = ref.watch(hostChargersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'My Stations',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF111827)),
            onPressed: () => context.push('/add-charger'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: chargersAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (chargers) {
          if (chargers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.ev_station_rounded, size: 64, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),
                  Text(
                    'No stations added yet.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chargers.length,
            itemBuilder: (context, index) {
              final charger = chargers[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: charger.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: charger.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFFF3F4F6),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, size: 30),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFFF0FDF4),
                              child: const Icon(Icons.ev_station_rounded, color: Color(0xFF22C55E)),
                            ),
                    ),
                    title: Text(
                      charger.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '₹${charger.pricePerHour.toStringAsFixed(0)} / hr',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF22C55E),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          charger.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: charger.available,
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(chargerServiceProvider).updateCharger(
                                  charger.id,
                                  {'isAvailable': value},
                                );
                          } catch (e) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update status'),
                              ),
                            );
                          }
                        },
                        activeColor: const Color(0xFF22C55E),
                        activeTrackColor: const Color(0xFFDCFCE7),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
