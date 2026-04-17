import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/booking_model.dart';
import '../../charger/models/charger_model.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingSuccessScreen extends StatelessWidget {
  final BookingModel booking;
  final ChargerModel charger;

  const BookingSuccessScreen({super.key, required this.booking, required this.charger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF22C55E), // Brand Green
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.check_circle, size: 100, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your time slot at ${charger.name} has been successfully reserved.',
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'BOOKING ID: ${booking.id.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'While you charge...',
                        style: GoogleFonts.inter(
                          fontSize: 18, 
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_cafe_rounded, color: Color(0xFFF97316)),
                        ),
                        title: Text('Nearby Cafe', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Starbucks • 0.2 km', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () {},
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF3B82F6)),
                        ),
                        title: Text('Shopping Mall', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Westfield • 0.5 km', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Launching Maps...')),
                    );
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: Text('Get Directions', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/live-session', extra: booking);
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text('Check-in to Charger', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
