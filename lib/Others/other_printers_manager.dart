import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer_platform_interface.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

class OtherPrinterManager {
  OtherPrinterManager._privateConstructor();

  static OtherPrinterManager? _instance;

  static OtherPrinterManager get instance {
    _instance ??= OtherPrinterManager._privateConstructor();
    return _instance!;
  }

  final StreamController<List<Printer>> _devicesstream =
      StreamController<List<Printer>>.broadcast();

  Stream<List<Printer>> get devicesStream => _devicesstream.stream;
  StreamSubscription? subscription;

  static String channelName = 'flutter_thermal_printer/events';

  // Start scanning for BLE devices
  Future<void> startScan() async {}

  // Stop scanning for BLE devices
  Future<void> stopScan({
    bool stopBle = true,
    bool stopUsb = true,
  }) async {
    try {
      if (stopBle) {
        await subscription?.cancel();
      }
      if (stopUsb) {
        await _usbSubscription?.cancel();
      }
      if (refresher != null && stopBle && stopUsb) {
        await refresher?.cancel();
      }
    } catch (e) {
      log('Failed to stop scanning for devices $e');
    }
  }

  Future<bool> connect(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return await FlutterThermalPrinterPlatform.instance.connect(device);
    }
    return false;
  }

  Future<bool> isConnected(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return await FlutterThermalPrinterPlatform.instance.isConnected(device);
    }
    return false;
  }

  Future<void> disconnect(Printer device) async {}

  // Print data to BLE device
  Future<void> printData(
    Printer printer,
    List<int> bytes, {
    bool longData = false,
  }) async {
    if (printer.connectionType == ConnectionType.USB) {
      try {
        await FlutterThermalPrinterPlatform.instance.printText(
          printer,
          Uint8List.fromList(bytes),
          path: printer.address,
        );
      } catch (e) {
        log("FlutterThermalPrinter: Unable to Print Data $e");
      }
    }
  }

  StreamSubscription? _usbSubscription;

  // USB
  Future<dynamic> startUsbScan({
    Duration refreshDuration = const Duration(seconds: 5),
  }) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      _usbSubscription?.cancel();
      _usbSubscription =
          Stream.periodic(refreshDuration, (x) => x).listen((event) async {
        List<Printer> list = [];
        final devices =
            await FlutterThermalPrinterPlatform.instance.startUsbScan();
        for (var e in devices) {
          final map =
              Map<String, dynamic>.from(e is String ? jsonDecode(e) : e);
          final device = Printer(
            vendorId: map['vendorId']?.toString(),
            productId: map['productId']?.toString(),
            name: map['name']?.toString(),
            connectionType: ConnectionType.USB,
            address: map['bsdPath']?.toString() ?? map['vendorId']?.toString(),
            isConnected: false,
          );
          final isConnected =
              await FlutterThermalPrinterPlatform.instance.isConnected(device);
          device.isConnected = isConnected;
          list.add(device);
        }
        _devicesstream.add(list);
      });
      return;
    } else {
      throw Exception('Unsupported Platform');
    }
  }

  StreamSubscription? refresher;

  // Get Printers from BT and USB
  void getPrinters({
    Duration refreshDuration = const Duration(seconds: 5),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.BLE,
      ConnectionType.USB,
    ],
  }) async {
    if (connectionTypes.isEmpty) {
      return;
    }
    if (refresher != null) {
      refresher?.cancel();
      refresher = null;
    }
    List<Printer> btlist = [];

    List<Printer> list = [];
    if (connectionTypes.contains(ConnectionType.USB)) {
      _usbSubscription?.cancel();
      _usbSubscription =
          Stream.periodic(refreshDuration, (x) => x).listen((event) async {
        final devices =
            await FlutterThermalPrinterPlatform.instance.startUsbScan();
        List<Printer> templist = [];
        for (var e in devices) {
          final map =
              Map<String, dynamic>.from(e is String ? jsonDecode(e) : e);
          final device = Printer(
            vendorId: map['vendorId'].toString(),
            productId: map['productId'].toString(),
            name: map['name'],
            connectionType: ConnectionType.USB,
            address: map['vendorId'].toString(),
            isConnected: false,
          );
          final isConnected =
              await FlutterThermalPrinterPlatform.instance.isConnected(device);
          device.isConnected = isConnected;
          templist.add(device);
        }
        list = templist;
      });
    }
    refresher = Stream.periodic(refreshDuration, (x) => x).listen((event) {
      _devicesstream.add(list + btlist);
    });
  }

  Future<dynamic> convertImageToGrayscale(Uint8List? value) async {
    return await FlutterThermalPrinterPlatform.instance
        .convertImageToGrayscale(value);
  }
}
