import 'dart:async';

/// Deterministic mock A2UI JSON streamer simulating multi-turn flight booking.
///
/// **Production Architecture Note**:
/// In production, these A2UI messages would originate as Server-Sent Events (SSE)
/// emitted by an enterprise AI Agent running in the cloud (for example Google Cloud Run
/// or Vertex AI Agent Builder). The agent would call external flight inventory
/// APIs (Sabre, Amadeus), format the resulting UI into A2UI JSON components, and stream
/// them chunk-by-chunk to the mobile client.
class FlightMockStreamer {
  /// Minimal catalog ID required by A2UI standard processor.
  static const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  /// Generates the initial flight search result discovery surface.
  static Stream<Map<String, dynamic>> streamDiscoverySurface({
    Duration delay = const Duration(milliseconds: 20),
  }) async* {
    const surfaceId = 'surf-flight-discovery';

    yield {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': minimalCatalogId,
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root_col',
            'component': 'Column',
            'crossAxisAlignment': 'stretch',
            'children': [
              {'id': 'card_flight'},
            ],
          },
          {
            'id': 'card_flight',
            'component': 'Card',
            'elevation': 2.0,
            'child': {'id': 'card_content'},
          },
          {
            'id': 'card_content',
            'component': 'Column',
            'crossAxisAlignment': 'start',
            'children': [
              {'id': 'flight_header_row'},
              {'id': 'route_row'},
              {'id': 'flight_divider'},
              {'id': 'action_row'},
            ],
          },
          {
            'id': 'flight_header_row',
            'component': 'Row',
            'mainAxisAlignment': 'spaceBetween',
            'children': [
              {'id': 'txt_airline'},
              {'id': 'txt_flight_num'},
            ],
          },
          {
            'id': 'txt_airline',
            'component': 'Text',
            'variant': 'title',
            'text': 'Pacific Rim Airways (Nonstop)',
          },
          {
            'id': 'txt_flight_num',
            'component': 'Text',
            'variant': 'caption',
            'text': 'PR-774 • Boeing 787-9',
          },
          {
            'id': 'route_row',
            'component': 'Row',
            'mainAxisAlignment': 'spaceBetween',
            'children': [
              {'id': 'txt_origin'},
              {'id': 'txt_arrow'},
              {'id': 'txt_dest'},
            ],
          },
          {
            'id': 'txt_origin',
            'component': 'Text',
            'variant': 'h2',
            'text': 'SFO 11:20 AM',
          },
          {
            'id': 'txt_arrow',
            'component': 'Text',
            'variant': 'title',
            'text': '✈️ 10h 45m ➔',
          },
          {
            'id': 'txt_dest',
            'component': 'Text',
            'variant': 'h2',
            'text': 'HND 3:05 PM +1',
          },
          {
            'id': 'flight_divider',
            'component': 'Divider',
          },
          {
            'id': 'action_row',
            'component': 'Row',
            'mainAxisAlignment': 'spaceBetween',
            'children': [
              {'id': 'txt_starting_price'},
              {'id': 'btn_select_flight'},
            ],
          },
          {
            'id': 'txt_starting_price',
            'component': 'Text',
            'variant': 'title',
            'text': 'From \$420 USD',
          },
          {
            'id': 'btn_select_flight',
            'component': 'Button',
            'variant': 'primary',
            'child': {'id': 'txt_btn_select'},
            'action': {
              'name': 'selectFlight',
              'context': {
                'flightNumber': 'PR-774',
                'origin': 'SFO',
                'destination': 'HND',
                'baseFare': 420,
              },
            },
          },
          {
            'id': 'txt_btn_select',
            'component': 'Text',
            'variant': 'body',
            'text': 'Select This Flight',
          },
        ],
      },
    };
  }

  /// Generates the interactive seat customization and passenger form surface.
  static Stream<Map<String, dynamic>> streamCustomizationSurface({
    Duration delay = const Duration(milliseconds: 20),
  }) async* {
    const surfaceId = 'surf-seat-customization';

    yield {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': minimalCatalogId,
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'cust_root',
            'component': 'Column',
            'crossAxisAlignment': 'stretch',
            'children': [
              {'id': 'txt_cust_title'},
              {'id': 'txt_cust_sub'},
              {'id': 'input_passenger_name'},
              {'id': 'input_seat_tier'},
              {'id': 'input_notes'},
              {'id': 'btn_proceed_booking'},
            ],
          },
          {
            'id': 'txt_cust_title',
            'component': 'Text',
            'variant': 'h2',
            'text': 'Passenger & Cabin Customization',
          },
          {
            'id': 'txt_cust_sub',
            'component': 'Text',
            'variant': 'caption',
            'text': 'Flight PR-774 (SFO ➔ HND) • Real-time reactive pricing',
          },
          {
            'id': 'input_passenger_name',
            'component': 'TextField',
            'label': 'Primary Passenger Full Name',
            'placeholder': 'Merlyn Schwartz',
            'value': {
              'path': '/passenger/name',
            },
          },
          {
            'id': 'input_seat_tier',
            'component': 'TextField',
            'label': 'Cabin Tier (Economy / Premium / Business)',
            'placeholder': 'Economy',
            'helperText':
                'Economy (\$420) • Premium (\$650) • Business (\$1250)',
            'value': {
              'path': '/booking/tier',
            },
          },
          {
            'id': 'input_notes',
            'component': 'TextField',
            'label': 'Special Dietary / Assistance Notes',
            'placeholder': 'Vegetarian meal, extra pillows, etc.',
            'value': {
              'path': '/booking/notes',
            },
          },
          {
            'id': 'btn_proceed_booking',
            'component': 'Button',
            'variant': 'primary',
            'child': {'id': 'txt_btn_proceed'},
            'action': {
              'name': 'proceedBooking',
              'context': {
                'step': 'confirmation_ready',
              },
            },
          },
          {
            'id': 'txt_btn_proceed',
            'component': 'Text',
            'variant': 'body',
            'text': 'Continue to Confirmation',
          },
        ],
      },
    };
  }

  /// Generates the final booking confirmation receipt surface.
  static Stream<Map<String, dynamic>> streamConfirmationSurface({
    required String passengerName,
    required String seatTier,
    required int finalPrice,
    Duration delay = const Duration(milliseconds: 20),
  }) async* {
    const surfaceId = 'surf-booking-confirmation';

    yield {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': minimalCatalogId,
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'conf_root',
            'component': 'Card',
            'elevation': 3.0,
            'child': {'id': 'conf_col'},
          },
          {
            'id': 'conf_col',
            'component': 'Column',
            'crossAxisAlignment': 'start',
            'children': [
              {'id': 'txt_conf_badge'},
              {'id': 'txt_pnr'},
              {'id': 'conf_divider_1'},
              {'id': 'txt_conf_passenger'},
              {'id': 'txt_conf_flight'},
              {'id': 'txt_conf_tier'},
              {'id': 'conf_divider_2'},
              {'id': 'txt_conf_total'},
              {'id': 'btn_new_search'},
            ],
          },
          {
            'id': 'txt_conf_badge',
            'component': 'Text',
            'variant': 'h2',
            'text': '🎉 Booking Confirmed!',
          },
          {
            'id': 'txt_pnr',
            'component': 'Text',
            'variant': 'title',
            'text': 'PNR Reference: PR-9942XJ',
          },
          {
            'id': 'conf_divider_1',
            'component': 'Divider',
          },
          {
            'id': 'txt_conf_passenger',
            'component': 'Text',
            'variant': 'body',
            'text': 'Passenger: $passengerName',
          },
          {
            'id': 'txt_conf_flight',
            'component': 'Text',
            'variant': 'body',
            'text': 'Flight: PR-774 (SFO ➔ HND Nonstop)',
          },
          {
            'id': 'txt_conf_tier',
            'component': 'Text',
            'variant': 'body',
            'text': 'Cabin: $seatTier',
          },
          {
            'id': 'conf_divider_2',
            'component': 'Divider',
          },
          {
            'id': 'txt_conf_total',
            'component': 'Text',
            'variant': 'h3',
            'text': 'Total Paid: \$$finalPrice USD',
          },
          {
            'id': 'btn_new_search',
            'component': 'Button',
            'variant': 'borderless',
            'child': {'id': 'txt_btn_new'},
            'action': {
              'name': 'restartSearch',
            },
          },
          {
            'id': 'txt_btn_new',
            'component': 'Text',
            'variant': 'body',
            'text': 'Book Another Flight',
          },
        ],
      },
    };
  }
}
