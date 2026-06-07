import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider chatMockupFileImage(String absolutePath) {
  return FileImage(File(absolutePath));
}
