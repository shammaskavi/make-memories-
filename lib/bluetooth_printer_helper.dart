import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'dart:typed_data'; // <-- Add this at the top

class BluetoothPrinterHelper {
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  Future<void> initPrinter() async {
    bool isConnected = await printer.isConnected ?? false;
    if (!isConnected) {
      List<BluetoothDevice> devices = await printer.getBondedDevices();
      // Try to auto-select MPT-II or the first available device
      BluetoothDevice? target = devices.firstWhere(
        (d) => d.name?.toUpperCase().contains('MPT-II') ?? false,
        orElse: () => devices.first,
      );
      await printer.connect(target);
    }
  }

  Future<void> printImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return;

    // Resize image to printer width (MPT-II is usually 384px wide for 58mm paper)
    final resized = img.copyResize(image, width: 384);
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final rasterBytes = generator.image(resized, align: PosAlign.center);

    await printer.writeBytes(Uint8List.fromList(rasterBytes));
    await printer.writeBytes(Uint8List.fromList(generator.feed(2)));
    await printer.writeBytes(Uint8List.fromList(generator.cut()));
  }
}
