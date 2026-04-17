import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/charger_provider.dart';

class MyChargersScreen extends ConsumerWidget {
  const MyChargersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargersAsyncValue = ref.watch(hostChargersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chargers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-charger'),
          ),
        ],
      ),
      body: chargersAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: \$err')),
        data: (chargers) {
          if (chargers.isEmpty) {
            return const Center(child: Text('No chargers added yet.'));
          }

          return ListView.builder(
            itemCount: chargers.length,
            itemBuilder: (context, index) {
              final charger = chargers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: charger.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: charger.photos.first,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image,
                            size: 50,
                          ),
                        )
                      : const Icon(Icons.ev_station, size: 50),
                  title: Text(charger.title),
                  subtitle: Text('\$ \${charger.pricePerHour.toStringAsFixed(2)} / hr\\n\${charger.address}'),
                  isThreeLine: true,
                  trailing: Switch(
                    value: charger.isAvailable,
                    onChanged: (value) async {
                      try {
                        await ref.read(chargerServiceProvider).updateCharger(charger.id, {'isAvailable': value});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status')));
                      }
                    },
                    activeThumbColor: const Color(0xFF1DB954),
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
