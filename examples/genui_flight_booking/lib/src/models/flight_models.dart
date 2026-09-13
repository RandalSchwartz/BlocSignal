import 'package:flutter/foundation.dart';

/// Available cabin seat tiers.
enum SeatTier {
  /// Standard economy seat.
  economy('Economy', 420),

  /// Premium economy with extra legroom.
  premium('Premium Economy', 650),

  /// Lie-flat business class seat.
  business('Business Class', 1250);

  const SeatTier(this.label, this.basePrice);

  /// Human-readable title of the tier.
  final String label;

  /// Base price in USD.
  final int basePrice;
}

/// Flight booking details model.
@immutable
class FlightDetails {
  /// Creates a [FlightDetails].
  const FlightDetails({
    required this.flightNumber,
    required this.airline,
    required this.originCode,
    required this.originCity,
    required this.destinationCode,
    required this.destinationCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
  });

  final String flightNumber;
  final String airline;
  final String originCode;
  final String originCity;
  final String destinationCode;
  final String destinationCity;
  final String departureTime;
  final String arrivalTime;
  final String duration;
}
