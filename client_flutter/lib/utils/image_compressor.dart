import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Max pixels before we auto-downscale an inserted image (2 MP).
const int _maxImagePixels = 2000000;

/// Files smaller than this are left untouched — compression overhead isn't
/// worth it for a 200 KB attachment, and JPEG re-encoding may even grow them.
const int _minCompressBytes = 800 * 1024; // 800KB

/// Re-encode an image, preserving its original format.
///
/// - Files smaller than [_minCompressBytes] are returned as-is.
/// - If it exceeds [_maxImagePixels] we downscale preserving aspect ratio.
/// - JPEG sources are re-encoded with quality=85.
/// - PNG sources stay PNG (lossless, no quality knob).
/// - Animated formats (GIF, animated WebP, APNG) are returned as-is.
/// - When the result is larger than the source, the original bytes are
///   returned untouched.
Future<Uint8List> compressStaticImage(String sourcePath) async {
  // Fast path — skip without reading the whole file into memory
  final fileSize = await File(sourcePath).length();
  if (fileSize < _minCompressBytes) {
    return File(sourcePath).readAsBytes();
  }

  final source = await File(sourcePath).readAsBytes();

  final decoded = img.decodeImage(source);
  if (decoded == null) return source; // unknown format — copy as-is

  // Animated — skip, don't flatten
  if (decoded.frames.length > 1) return source;

  // Detect original format from file extension (the image library drops this
  // after decoding, and its `format` field refers to pixel color format, not
  // file container).
  final ext = sourcePath.split('.').last.toLowerCase();
  final isJpeg = ext == 'jpg' || ext == 'jpeg';
  final isPng = ext == 'png';
  final isWebp = ext == 'webp';

  // Downscale if over pixel budget
  final pixels = decoded.width * decoded.height;
  final img.Image prepared;
  if (pixels > _maxImagePixels) {
    final ratio = _maxImagePixels / pixels;
    final scale = math.sqrt(ratio);
    final targetW = (decoded.width * scale).round();
    final targetH = (decoded.height * scale).round();
    prepared = img.copyResize(decoded, width: targetW, height: targetH);
  } else {
    prepared = decoded;
  }

  // Re-encode in the original format so PNG stays PNG, JPEG stays JPEG, etc.
  final Uint8List encoded;
  if (isJpeg) {
    encoded = Uint8List.fromList(img.encodeJpg(prepared, quality: 85));
  } else if (isPng) {
    encoded = Uint8List.fromList(img.encodePng(prepared));
  } else if (isWebp) {
    // Lossy WebP — encoder class, no top-level function in the library
    final encoder = img.WebPEncoder(lossless: false, quality: 85);
    encoded = encoder.encode(prepared);
  } else {
    return source;
  }

  if (encoded.length >= source.length) {
    return source; // compression grew the file — keep original
  }
  return encoded;
}
