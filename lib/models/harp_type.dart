enum HarpType { lapHarp, leverHarp, pedalHarp }

extension HarpTypeExt on HarpType {
  String get displayName {
    switch (this) {
      case HarpType.lapHarp:    return 'Lap Harp';
      case HarpType.leverHarp:  return 'Lever Harp';
      case HarpType.pedalHarp:  return 'Pedal Harp';
    }
  }

  String get subtitle {
    switch (this) {
      case HarpType.lapHarp:    return '15 strings · C4–C6';
      case HarpType.leverHarp:  return '34 strings · A1–F6';
      case HarpType.pedalHarp:  return '47 strings · C1–G7';
    }
  }

  String get description {
    switch (this) {
      case HarpType.lapHarp:
        return 'Compact diatonic harp, ideal for beginners and folk music.';
      case HarpType.leverHarp:
        return 'Celtic folk harp with lever mechanism for sharping individual strings.';
      case HarpType.pedalHarp:
        return 'Concert grand harp with full chromatic range via seven pedals.';
    }
  }
}
