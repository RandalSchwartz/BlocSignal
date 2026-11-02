/// Represents a preloaded A2UI Generative UI scenario in the playground.
class const PlaygroundScenario({
  required final String id,
  required final String name,
  required final String description,
  required final String jsonPayload,
});

/// Catalog of preloaded A2UI scenarios for the live playground.
class const PlaygroundScenarios() {
  /// 1. Flight Booking Scenario
  static const PlaygroundScenario flightBooking = PlaygroundScenario(
    id: 'flight-booking',
    name: 'Flight Booking',
    description: 'Interactive flight itinerary card with price summary and confirmation action.',
    jsonPayload: '''[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "flight-booking",
      "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    }
  },
  {
    "version": "v0.9",
    "updateDataModel": {
      "surfaceId": "flight-booking",
      "path": "/flight",
      "value": {
        "airline": "Pacific Rim Airways",
        "flightNumber": "PR-774 • Boeing 787-9",
        "origin": "SFO 11:20 AM",
        "destination": "HND 3:05 PM +1",
        "seat": "14A (Window, Economy Plus)",
        "price": "\$420 USD"
      }
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "flight-booking",
      "components": [
        {
          "id": "root",
          "component": "Card",
          "properties": {
            "child": "main_col"
          }
        },
        {
          "id": "main_col",
          "component": "Column",
          "properties": {
            "children": [
              "title_txt",
              "airline_txt",
              "route_row",
              "div_1",
              "seat_txt",
              "price_txt",
              "confirm_btn"
            ]
          }
        },
        {
          "id": "title_txt",
          "component": "Text",
          "properties": {
            "variant": "h3",
            "text": "Flight Reservation"
          }
        },
        {
          "id": "airline_txt",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": {
              "path": "/flight/airline"
            }
          }
        },
        {
          "id": "route_row",
          "component": "Row",
          "properties": {
            "children": [
              "origin_txt",
              "arrow_txt",
              "dest_txt"
            ]
          }
        },
        {
          "id": "origin_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": {
              "path": "/flight/origin"
            }
          }
        },
        {
          "id": "arrow_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": " ➔ "
          }
        },
        {
          "id": "dest_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": {
              "path": "/flight/destination"
            }
          }
        },
        {
          "id": "div_1",
          "component": "Divider",
          "properties": {}
        },
        {
          "id": "seat_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": {
              "path": "/flight/seat"
            }
          }
        },
        {
          "id": "price_txt",
          "component": "Text",
          "properties": {
            "variant": "h4",
            "text": {
              "path": "/flight/price"
            }
          }
        },
        {
          "id": "confirm_btn",
          "component": "Button",
          "properties": {
            "child": "confirm_btn_txt",
            "action": {
              "event": {
                "name": "confirm_booking",
                "context": {
                  "flightNumber": "PR-774",
                  "status": "confirmed"
                }
              }
            }
          }
        },
        {
          "id": "confirm_btn_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": "Confirm Reservation"
          }
        }
      ]
    }
  }
]''',
  );

  /// 2. Survey Form Scenario
  static const PlaygroundScenario surveyForm = PlaygroundScenario(
    id: 'survey-form',
    name: 'Customer Survey',
    description: 'Developer feedback form with two-way data bound text fields and submit action.',
    jsonPayload: '''[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "survey-form",
      "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    }
  },
  {
    "version": "v0.9",
    "updateDataModel": {
      "surfaceId": "survey-form",
      "path": "/survey",
      "value": {
        "email": "developer@example.com",
        "comments": "Signals + A2UI is blazing fast!"
      }
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "survey-form",
      "components": [
        {
          "id": "root",
          "component": "Card",
          "properties": {
            "child": "survey_col"
          }
        },
        {
          "id": "survey_col",
          "component": "Column",
          "properties": {
            "children": [
              "survey_title",
              "survey_lead",
              "email_input",
              "comments_input",
              "div_s",
              "submit_btn"
            ]
          }
        },
        {
          "id": "survey_title",
          "component": "Text",
          "properties": {
            "variant": "h3",
            "text": "Developer Feedback Survey"
          }
        },
        {
          "id": "survey_lead",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": "Help us improve bloc_signals_genui and generative UI protocols."
          }
        },
        {
          "id": "email_input",
          "component": "TextField",
          "properties": {
            "label": "Work Email",
            "value": {
              "path": "/survey/email"
            }
          }
        },
        {
          "id": "comments_input",
          "component": "TextField",
          "properties": {
            "label": "Feedback Comments",
            "variant": "longText",
            "value": {
              "path": "/survey/comments"
            }
          }
        },
        {
          "id": "div_s",
          "component": "Divider",
          "properties": {}
        },
        {
          "id": "submit_btn",
          "component": "Button",
          "properties": {
            "child": "submit_btn_txt",
            "action": {
              "event": {
                "name": "submit_survey",
                "context": {
                  "source": "web_playground"
                }
              }
            }
          }
        },
        {
          "id": "submit_btn_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": "Submit Feedback"
          }
        }
      ]
    }
  }
]''',
  );

  /// 3. Counter Card Scenario
  static const PlaygroundScenario counterCard = PlaygroundScenario(
    id: 'counter-card',
    name: 'Reactive Counter',
    description:
        'State card demonstrating dynamic text binding and button actions.',
    jsonPayload: '''[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "counter-card",
      "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    }
  },
  {
    "version": "v0.9",
    "updateDataModel": {
      "surfaceId": "counter-card",
      "path": "/counter",
      "value": {
        "count": "42",
        "status": "Active"
      }
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "counter-card",
      "components": [
        {
          "id": "root",
          "component": "Card",
          "properties": {
            "child": "counter_col"
          }
        },
        {
          "id": "counter_col",
          "component": "Column",
          "properties": {
            "children": [
              "counter_title",
              "counter_num",
              "status_txt",
              "div_c",
              "action_row"
            ]
          }
        },
        {
          "id": "counter_title",
          "component": "Text",
          "properties": {
            "variant": "h3",
            "text": "Reactive Counter"
          }
        },
        {
          "id": "counter_num",
          "component": "Text",
          "properties": {
            "variant": "h1",
            "text": {
              "path": "/counter/count"
            }
          }
        },
        {
          "id": "status_txt",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": {
              "path": "/counter/status"
            }
          }
        },
        {
          "id": "div_c",
          "component": "Divider",
          "properties": {}
        },
        {
          "id": "action_row",
          "component": "Row",
          "properties": {
            "children": [
              "dec_btn",
              "inc_btn"
            ]
          }
        },
        {
          "id": "dec_btn",
          "component": "Button",
          "properties": {
            "child": "dec_btn_txt",
            "action": {
              "event": {
                "name": "decrement",
                "context": {
                  "step": 1
                }
              }
            }
          }
        },
        {
          "id": "dec_btn_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": "➖ Decrement"
          }
        },
        {
          "id": "inc_btn",
          "component": "Button",
          "properties": {
            "child": "inc_btn_txt",
            "action": {
              "event": {
                "name": "increment",
                "context": {
                  "step": 1
                }
              }
            }
          }
        },
        {
          "id": "inc_btn_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": "➕ Increment"
          }
        }
      ]
    }
  }
]''',
  );

  /// 4. Multi-Surface Scenario
  static const PlaygroundScenario multiSurface = PlaygroundScenario(
    id: 'multi-surface',
    name: 'Multi-Surface Layout',
    description: 'Dual-surface architecture with master list surface and detail inspector surface.',
    jsonPayload: '''[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "multi-surface",
      "catalogId": "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    }
  },
  {
    "version": "v0.9",
    "updateDataModel": {
      "surfaceId": "multi-surface",
      "path": "/catalog",
      "value": {
        "packageName": "bloc_signals_genui_jaspr",
        "description": "Jaspr web component bindings for Generative UI (A2UI)",
        "version": "v1.0.0",
        "platform": "Web (Jaspr HTML DOM)"
      }
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "multi-surface",
      "components": [
        {
          "id": "root",
          "component": "Card",
          "properties": {
            "child": "master_col"
          }
        },
        {
          "id": "master_col",
          "component": "Column",
          "properties": {
            "children": [
              "master_title",
              "package_title",
              "package_desc",
              "div_m",
              "detail_row",
              "action_btn"
            ]
          }
        },
        {
          "id": "master_title",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": "Package Master Index"
          }
        },
        {
          "id": "package_title",
          "component": "Text",
          "properties": {
            "variant": "h3",
            "text": {
              "path": "/catalog/packageName"
            }
          }
        },
        {
          "id": "package_desc",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": {
              "path": "/catalog/description"
            }
          }
        },
        {
          "id": "div_m",
          "component": "Divider",
          "properties": {}
        },
        {
          "id": "detail_row",
          "component": "Row",
          "properties": {
            "children": [
              "ver_txt",
              "platform_txt"
            ]
          }
        },
        {
          "id": "ver_txt",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": {
              "path": "/catalog/version"
            }
          }
        },
        {
          "id": "platform_txt",
          "component": "Text",
          "properties": {
            "variant": "caption",
            "text": {
              "path": "/catalog/platform"
            }
          }
        },
        {
          "id": "action_btn",
          "component": "Button",
          "properties": {
            "child": "action_btn_txt",
            "action": {
              "event": {
                "name": "view_package_docs",
                "context": {
                  "route": "/docs/pkg-genui-jaspr"
                }
              }
            }
          }
        },
        {
          "id": "action_btn_txt",
          "component": "Text",
          "properties": {
            "variant": "body",
            "text": "Open Documentation 📖"
          }
        }
      ]
    }
  }
]''',
  );

  /// All registered preloaded scenarios.
  static const List<PlaygroundScenario> all = [
    flightBooking,
    surveyForm,
    counterCard,
    multiSurface,
  ];
}
