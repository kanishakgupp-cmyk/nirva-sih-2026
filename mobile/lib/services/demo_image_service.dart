import 'dart:typed_data';

import 'package:image/image.dart' as img;

class DemoImageService {
  const DemoImageService();

  Uint8List createDemoImage() {
    final image = img.Image(width: 640, height: 480);
    img.fill(image, color: img.ColorRgb8(230, 236, 232));
    img.drawRect(
      image,
      x1: 80,
      y1: 80,
      x2: 560,
      y2: 400,
      color: img.ColorRgb8(0, 105, 92),
      thickness: 8,
    );
    img.drawLine(
      image,
      x1: 120,
      y1: 240,
      x2: 520,
      y2: 240,
      color: img.ColorRgb8(200, 70, 50),
      thickness: 10,
    );
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }
}
