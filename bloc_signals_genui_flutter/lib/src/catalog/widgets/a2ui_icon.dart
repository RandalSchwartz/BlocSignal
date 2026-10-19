import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

const Map<String, IconData> _a2uiIconMap = <String, IconData>{
  'accountCircle': Icons.account_circle,
  'add': Icons.add,
  'arrowBack': Icons.arrow_back,
  'arrowForward': Icons.arrow_forward,
  'attachFile': Icons.attach_file,
  'calendarToday': Icons.calendar_today,
  'call': Icons.call,
  'camera': Icons.camera_alt,
  'check': Icons.check,
  'close': Icons.close,
  'delete': Icons.delete,
  'download': Icons.download,
  'edit': Icons.edit,
  'error': Icons.error,
  'event': Icons.event,
  'fastForward': Icons.fast_forward,
  'favorite': Icons.favorite,
  'favoriteOff': Icons.favorite_border,
  'folder': Icons.folder,
  'help': Icons.help,
  'home': Icons.home,
  'info': Icons.info,
  'locationOn': Icons.location_on,
  'lock': Icons.lock,
  'lockOpen': Icons.lock_open,
  'mail': Icons.mail,
  'menu': Icons.menu,
  'moreHoriz': Icons.more_horiz,
  'moreVert': Icons.more_vert,
  'notifications': Icons.notifications,
  'notificationsOff': Icons.notifications_off,
  'pause': Icons.pause,
  'payment': Icons.payment,
  'person': Icons.person,
  'phone': Icons.phone,
  'photo': Icons.photo,
  'play': Icons.play_arrow,
  'print': Icons.print,
  'refresh': Icons.refresh,
  'rewind': Icons.fast_rewind,
  'search': Icons.search,
  'send': Icons.send,
  'settings': Icons.settings,
  'share': Icons.share,
  'shoppingCart': Icons.shopping_cart,
  'skipNext': Icons.skip_next,
  'skipPrevious': Icons.skip_previous,
  'star': Icons.star,
  'starHalf': Icons.star_half,
  'starOff': Icons.star_border,
  'stop': Icons.stop,
  'upload': Icons.upload,
  'visibility': Icons.visibility,
  'visibilityOff': Icons.visibility_off,
  'volumeDown': Icons.volume_down,
  'volumeMute': Icons.volume_mute,
  'volumeOff': Icons.volume_off,
  'volumeUp': Icons.volume_up,
  'warning': Icons.warning,
};

/// Renders an A2UI `Icon` component by mapping standard A2UI icon names to
/// Material [Icons], falling back to [Icons.help_outline] when unrecognized.
///
/// ```dart
/// final widget = buildA2uiIcon(context, componentContext);
/// ```
Widget buildA2uiIcon(
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

  final iconData = _a2uiIconMap[iconName] ?? Icons.help_outline;
  final size = props['size'] != null ? asDouble(props['size'], 24) : 24.0;
  final semanticLabel = unwrapBinding(props['description'])?.toString();

  return Icon(
    iconData,
    size: size,
    semanticLabel: semanticLabel,
  );
}
