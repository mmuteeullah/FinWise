import 'package:flutter/services.dart';
import '../models/sms_message.dart';

class SmsService {
  static const platform = MethodChannel('com.mmuteeullah.finwise/sms');

  Future<List<SmsMessage>> getMessages() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getMessages');
      return result.map((item) => SmsMessage.fromMap(item)).toList();
    } on PlatformException catch (e) {
      print("Failed to get messages: '${e.message}'.");
      return [];
    }
  }

  Future<void> clearMessages() async {
    try {
      await platform.invokeMethod('clearMessages');
    } on PlatformException catch (e) {
      print("Failed to clear messages: '${e.message}'.");
    }
  }
}
