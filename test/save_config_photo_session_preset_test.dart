import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveConfig.usePhotoSessionPreset', () {
    test('is off by default for every constructor', () {
      expect(SaveConfig.photo().usePhotoSessionPreset, isFalse);
      expect(SaveConfig.video().usePhotoSessionPreset, isFalse);
      expect(SaveConfig.photoAndVideo().usePhotoSessionPreset, isFalse);
    });

    test('SaveConfig.photo keeps the value it is given', () {
      expect(
        SaveConfig.photo(usePhotoSessionPreset: true).usePhotoSessionPreset,
        isTrue,
      );
    });
  });
}
