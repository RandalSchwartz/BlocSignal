import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

const Map<String, IconData> _a2uiCupertinoIconMap = <String, IconData>{
  'accountCircle': CupertinoIcons.person_crop_circle,
  'add': CupertinoIcons.add,
  'arrowBack': CupertinoIcons.back,
  'arrowForward': CupertinoIcons.forward,
  'attachFile': CupertinoIcons.paperclip,
  'calendarToday': CupertinoIcons.calendar_today,
  'call': CupertinoIcons.phone,
  'camera': CupertinoIcons.camera,
  'check': CupertinoIcons.check_mark,
  'close': CupertinoIcons.clear,
  'delete': CupertinoIcons.delete,
  'download': CupertinoIcons.down_arrow,
  'edit': CupertinoIcons.pencil,
  'error': CupertinoIcons.exclamationmark_circle,
  'event': CupertinoIcons.calendar,
  'fastForward': CupertinoIcons.forward_fill,
  'favorite': CupertinoIcons.heart_fill,
  'favoriteOff': CupertinoIcons.heart,
  'folder': CupertinoIcons.folder,
  'help': CupertinoIcons.question_circle,
  'home': CupertinoIcons.home,
  'info': CupertinoIcons.info_circle,
  'locationOn': CupertinoIcons.location_solid,
  'lock': CupertinoIcons.lock,
  'lockOpen': CupertinoIcons.lock_open,
  'mail': CupertinoIcons.mail,
  'menu': CupertinoIcons.bars,
  'moreHoriz': CupertinoIcons.ellipsis,
  'moreVert': CupertinoIcons.ellipsis_vertical,
  'notifications': CupertinoIcons.bell_fill,
  'notificationsOff': CupertinoIcons.bell_slash,
  'pause': CupertinoIcons.pause,
  'payment': CupertinoIcons.creditcard,
  'person': CupertinoIcons.person,
  'phone': CupertinoIcons.phone,
  'photo': CupertinoIcons.photo,
  'play': CupertinoIcons.play_arrow,
  'print': CupertinoIcons.printer,
  'refresh': CupertinoIcons.refresh,
  'rewind': CupertinoIcons.backward_fill,
  'search': CupertinoIcons.search,
  'send': CupertinoIcons.paperplane,
  'settings': CupertinoIcons.settings,
  'share': CupertinoIcons.share,
  'shoppingCart': CupertinoIcons.shopping_cart,
  'skipNext': CupertinoIcons.forward_end_fill,
  'skipPrevious': CupertinoIcons.backward_end_fill,
  'star': CupertinoIcons.star_fill,
  'starHalf': CupertinoIcons.star_lefthalf_fill,
  'starOff': CupertinoIcons.star,
  'stop': CupertinoIcons.stop_fill,
  'upload': CupertinoIcons.up_arrow,
  'visibility': CupertinoIcons.eye,
  'visibilityOff': CupertinoIcons.eye_slash,
  'volumeDown': CupertinoIcons.volume_down,
  'volumeMute': CupertinoIcons.volume_mute,
  'volumeOff': CupertinoIcons.volume_off,
  'volumeUp': CupertinoIcons.volume_up,
  'warning': CupertinoIcons.exclamationmark_triangle,
};

/// Renders an A2UI `Icon` component by mapping standard A2UI icon names to
/// [CupertinoIcons], falling back to [CupertinoIcons.question_circle] when
/// unrecognized.
///
/// ```dart
/// final widget = buildCupertinoIcon(context, componentContext);
/// ```
Widget buildCupertinoIcon(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final rawName = unwrapBinding(props['name'] ?? props['icon']);
  final String iconName;
  if (rawName is Map) {
    iconName = asString(rawName['name'] ?? rawName['svgPath']);
  } else {
    iconName = asString(rawName);
  }

  final iconData =
      _a2uiCupertinoIconMap[iconName] ?? CupertinoIcons.question_circle;
  final size = props['size'] != null ? asDouble(props['size'], 24) : 24.0;
  final semanticLabel = unwrapBinding(props['description'])?.toString();

  return Icon(
    iconData,
    size: size,
    semanticLabel: semanticLabel,
  );
}
