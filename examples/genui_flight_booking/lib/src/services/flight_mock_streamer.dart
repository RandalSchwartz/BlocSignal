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

  /// Basic catalog ID for A2UI v0.9 supporting all 16 standard components,
  /// `CheckRule` validation (`checks`), and `ChildList` template expansion.
  static const basicCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  /// Generates the initial flight search result discovery surface using
  /// `NodeResolver` `ChildList` template expansion over `/flights`.
  static Stream<Map<String, dynamic>> streamDiscoverySurface({
    Duration delay = const Duration(milliseconds: 20),
  }) async* {
    const surfaceId = 'surf-flight-discovery';

    yield {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': basicCatalogId,
      },
    };
    // [PRODUCTION CONSIDERATION]: In production, this client-side mock delay
    // is replaced by real network chunk arrival over SSE or WebSockets.
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': surfaceId,
        'path': '/flights',
        'value': [
          {
            'airline': 'Pacific Rim Airways (Nonstop)',
            'flightNumber': 'PR-774 • Boeing 787-9',
            'origin': 'SFO 11:20 AM',
            'duration': '✈️ 10h 45m ➔',
            'destination': 'HND 3:05 PM +1',
            'priceDisplay': 'From \$420 USD',
            'baseFare': 420,
          },
          {
            'airline': 'Pacific Rim Airways (Evening)',
            'flightNumber': 'PR-882 • Airbus A350-1000',
            'origin': 'SFO 4:45 PM',
            'duration': '✈️ 11h 00m ➔',
            'destination': 'HND 8:45 PM +1',
            'priceDisplay': 'From \$460 USD',
            'baseFare': 460,
          },
        ],
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'align': 'stretch',
            'children': {
              'componentId': 'card_flight',
              'path': '/flights',
            },
          },
          {
            'id': 'card_flight',
            'component': 'Card',
            'child': 'card_content',
          },
          {
            'id': 'card_content',
            'component': 'Column',
            'align': 'start',
            'children': [
              'flight_header_row',
              'route_row',
              'flight_divider',
              'action_row',
            ],
          },
          {
            'id': 'flight_header_row',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': [
              'txt_airline',
              'txt_flight_num',
            ],
          },
          {
            'id': 'txt_airline',
            'component': 'Text',
            'variant': 'h4',
            'text': {'path': 'airline'},
          },
          {
            'id': 'txt_flight_num',
            'component': 'Text',
            'variant': 'caption',
            'text': {'path': 'flightNumber'},
          },
          {
            'id': 'route_row',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': [
              'txt_origin',
              'txt_arrow',
              'txt_dest',
            ],
          },
          {
            'id': 'txt_origin',
            'component': 'Text',
            'variant': 'h4',
            'text': {'path': 'origin'},
          },
          {
            'id': 'txt_arrow',
            'component': 'Text',
            'variant': 'body',
            'text': {'path': 'duration'},
          },
          {
            'id': 'txt_dest',
            'component': 'Text',
            'variant': 'h4',
            'text': {'path': 'destination'},
          },
          {
            'id': 'flight_divider',
            'component': 'Divider',
          },
          {
            'id': 'action_row',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': [
              'txt_starting_price',
              'btn_select_flight',
            ],
          },
          {
            'id': 'txt_starting_price',
            'component': 'Text',
            'variant': 'h4',
            'text': {'path': 'priceDisplay'},
          },
          {
            'id': 'btn_select_flight',
            'component': 'Button',
            'variant': 'primary',
            'child': 'txt_btn_select',
            'action': {
              'event': {
                'name': 'selectFlight',
                'context': {
                  'flightNumber': {'path': 'flightNumber'},
                  'baseFare': {'path': 'baseFare'},
                },
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

  /// Generates the interactive seat customization and passenger form surface
  /// showcasing `BasicCatalog` v0.9 widgets (`ChoicePicker`, `CheckBox`,
  /// `DateTimeInput`, `TextField`, `Button`), `CheckRule` (`checks`), and
  /// bidirectional RPC seat assignment.
  static Stream<Map<String, dynamic>> streamCustomizationSurface({
    Duration delay = const Duration(milliseconds: 20),
  }) async* {
    const surfaceId = 'surf-seat-customization';

    yield {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': surfaceId,
        'catalogId': basicCatalogId,
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': surfaceId,
        'path': '/',
        'value': {
          'passenger': {
            'name': 'Merlyn Schwartz',
          },
          'booking': {
            'tier': ['Economy'],
            'departureDate': '2026-10-15',
            'assignedSeat': 'Unassigned',
            'notes': '',
          },
          'addons': {
            'checkedLuggage': false,
            'priorityBoarding': false,
          },
        },
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'align': 'stretch',
            'children': [
              'txt_cust_title',
              'txt_cust_sub',
              'input_passenger_name',
              'input_departure_date',
              'input_seat_tier',
              'input_checked_luggage',
              'input_priority_boarding',
              'seat_rpc_row',
              'input_notes',
              'btn_proceed_booking',
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
            'value': {
              'path': '/passenger/name',
            },
            'checks': [
              {
                'condition': {
                  'call': 'required',
                  'args': {
                    'value': {'path': '/passenger/name'},
                  },
                },
                'message': 'Passenger name is required',
              },
            ],
          },
          {
            'id': 'input_departure_date',
            'component': 'DateTimeInput',
            'label': 'Departure Date',
            'enableDate': true,
            'enableTime': false,
            'value': {
              'path': '/booking/departureDate',
            },
          },
          {
            'id': 'input_seat_tier',
            'component': 'ChoicePicker',
            'label': 'Cabin Tier (Economy / Premium / Business)',
            'variant': 'mutuallyExclusive',
            'displayStyle': 'chips',
            'options': [
              {'label': 'Economy', 'value': 'Economy'},
              {'label': 'Premium Economy', 'value': 'Premium Economy'},
              {'label': 'Business Class', 'value': 'Business Class'},
            ],
            'value': {
              'path': '/booking/tier',
            },
          },
          {
            'id': 'input_checked_luggage',
            'component': 'CheckBox',
            'label': 'Checked Bag (+\$45)',
            'value': {
              'path': '/addons/checkedLuggage',
            },
          },
          {
            'id': 'input_priority_boarding',
            'component': 'CheckBox',
            'label': 'Priority Boarding (+\$30)',
            'value': {
              'path': '/addons/priorityBoarding',
            },
          },
          {
            'id': 'seat_rpc_row',
            'component': 'Row',
            'justify': 'spaceBetween',
            'children': [
              'txt_assigned_seat',
              'btn_assign_seat',
            ],
          },
          {
            'id': 'txt_assigned_seat',
            'component': 'Text',
            'variant': 'body',
            'text': {'path': '/booking/assignedSeat'},
          },
          {
            'id': 'btn_assign_seat',
            'component': 'Button',
            'variant': 'borderless',
            'child': 'txt_btn_assign_seat',
            'action': {
              'event': {
                'name': 'requestSeatAssignment',
              },
            },
          },
          {
            'id': 'txt_btn_assign_seat',
            'component': 'Text',
            'variant': 'body',
            'text': 'Assign Preferred Seat (RPC)',
          },
          {
            'id': 'input_notes',
            'component': 'TextField',
            'label': 'Special Dietary / Assistance Notes',
            'value': {
              'path': '/booking/notes',
            },
          },
          {
            'id': 'btn_proceed_booking',
            'component': 'Button',
            'variant': 'primary',
            'child': 'txt_btn_proceed',
            'checks': [
              {
                'condition': {
                  'call': 'required',
                  'args': {
                    'value': {'path': '/passenger/name'},
                  },
                },
                'message': 'Passenger name is required',
              },
            ],
            'action': {
              'event': {
                'name': 'proceedBooking',
                'context': {
                  'step': 'confirmation_ready',
                },
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
        'catalogId': basicCatalogId,
      },
    };
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    yield {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': 'root',
            'component': 'Card',
            'child': 'conf_col',
          },
          {
            'id': 'conf_col',
            'component': 'Column',
            'align': 'start',
            'children': [
              'txt_conf_badge',
              'txt_pnr',
              'conf_divider_1',
              'txt_conf_passenger',
              'txt_conf_flight',
              'txt_conf_tier',
              'conf_divider_2',
              'txt_conf_total',
              'btn_new_search',
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
            'variant': 'h4',
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
            'child': 'txt_btn_new',
            'action': {
              'event': {
                'name': 'restartSearch',
              },
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
