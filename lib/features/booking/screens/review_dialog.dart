import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../models/booking_model.dart';

class ReviewDialog extends ConsumerStatefulWidget {
  final BookingModel booking;
  const ReviewDialog({super.key, required this.booking});

  @override
  ConsumerState<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<ReviewDialog> {
  double _rating = 5.0;
  final _textController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      final db = FirebaseFirestore.instance;
      final reviewId = db.collection('reviews').doc().id;
      final chargerRef = db
          .collection('chargers')
          .doc(widget.booking.chargerUid);

      await db.runTransaction((transaction) async {
        // 1. Write the review
        transaction.set(db.collection('reviews').doc(reviewId), {
          'bookingId': widget.booking.id,
          'chargerUid': widget.booking.chargerUid,
          'renterUid': widget.booking.renterUid,
          'rating': _rating,
          'text': _textController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Update charger rating average
        final chargerDoc = await transaction.get(chargerRef);
        if (chargerDoc.exists) {
          final currentRating = (chargerDoc.data()?['rating'] ?? 0.0)
              .toDouble();
          final currentCount = chargerDoc.data()?['reviewCount'] ?? 0;

          final newCount = currentCount + 1;
          final newRating =
              ((currentRating * currentCount) + _rating) / newCount;

          transaction.update(chargerRef, {
            'rating': newRating,
            'reviewCount': newCount,
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate your session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = index + 1.0),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: 'Leave a comment (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Skip')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
