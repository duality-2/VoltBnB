import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../charger/models/charger_model.dart';

class ChargerDetailScreen extends ConsumerStatefulWidget {
  final ChargerModel charger;
  const ChargerDetailScreen({super.key, required this.charger});

  @override
  ConsumerState<ChargerDetailScreen> createState() =>
      _ChargerDetailScreenState();
}

class _ChargerDetailScreenState extends ConsumerState<ChargerDetailScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  double _durationHours = 1.0;

  Future<void> _startBooking() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    // In a fully integrated app, this would trigger payment & booking creation.
    // For now (frontend only), show a success message and go back.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Success'),
        content: Text(
          'Successfully booked \${widget.charger.title} for \${_durationHours}h.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // close dialog
              context.pop(); // go back
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final subtotal = widget.charger.pricePerHour * _durationHours;
    // final totalAmount = subtotal + (subtotal * 0.05);

    return Scaffold(
      appBar: AppBar(title: Text(widget.charger.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 250,
              child: widget.charger.photos.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.charger.photos.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.charger.photos[index],
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.ev_station,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.charger.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.charger.address,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amenities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.charger.amenities
                        .map((a) => Chip(label: Text(a)))
                        .toList(),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Book Time Slot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_selectedDate!),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                            );
                            if (date != null) {
                              setState(() => _selectedDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _selectedTime == null
                                ? 'Select Time'
                                : _selectedTime!.format(context),
                          ),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() => _selectedTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration (Hours)'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _durationHours > 0.5
                                ? () => setState(() => _durationHours -= 0.5)
                                : null,
                          ),
                          Text(
                            '\${_durationHours}h',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                setState(() => _durationHours += 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Price Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$ \${widget.charger.pricePerHour.toStringAsFixed(2)} x \${_durationHours}h',
                      ),
                      Text(
                        '\$ \${(widget.charger.pricePerHour * _durationHours).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service Fee (5%)'),
                      Text(
                        '\$ \${((widget.charger.pricePerHour * _durationHours) * 0.05).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$ \${((widget.charger.pricePerHour * _durationHours) + ((widget.charger.pricePerHour * _durationHours) * 0.05)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _startBooking,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
