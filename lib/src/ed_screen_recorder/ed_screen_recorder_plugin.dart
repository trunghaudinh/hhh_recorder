import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/record_output_model.dart';

class EdScreenRecorder {
  static const MethodChannel _channel = MethodChannel('ed_screen_recorder');

  Future<RecordOutput> startRecordScreen(
      {required String fileName,
      String? dirPathToSave,
      bool? addTimeCode = true,
      String? fileOutputFormat = "MPEG_4",
      String? fileExtension = "mp4",
      int? videoBitrate = 3000000,
      int? videoFrame = 30,
      required int width,
      required int height,
      required bool audioEnable}) async {
    var uuid = const Uuid();
    String videoHash = uuid.v1().replaceAll('-', '');
    var dateNow = DateTime.now().microsecondsSinceEpoch;
    var response = await _channel.invokeMethod('startRecordScreen', {
      "audioenable": audioEnable,
      "filename": fileName,
      "dirpathtosave": dirPathToSave,
      "addtimecode": addTimeCode,
      "videoframe": videoFrame,
      "videobitrate": videoBitrate,
      "fileoutputformat": fileOutputFormat,
      "fileextension": fileExtension,
      "videohash": videoHash,
      "startdate": dateNow,
      "width": width,
      "height": height,
    });
    var formatResponse = RecordOutput.fromJson(json.decode(response));
    if (kDebugMode) {
      debugPrint("""
      >>> Start Record Response Output:  
      File: ${formatResponse.file} 
      Event Name: ${formatResponse.eventName}  
      Progressing: ${formatResponse.isProgress} 
      Message: ${formatResponse.message} 
      Success: ${formatResponse.success} 
      Video Hash: ${formatResponse.videoHash} 
      Start Date: ${formatResponse.startDate} 
      End Date: ${formatResponse.endDate}
      Check Status: ${formatResponse.checkStatus} // Thêm checkStatus
      """);
    }
    return formatResponse;
  }

  Future<RecordOutput> stopRecord() async {
    var dateNow = DateTime.now().microsecondsSinceEpoch;
    var response = await _channel.invokeMethod('stopRecordScreen', {
      "enddate": dateNow,
    });

    var formatResponse = RecordOutput.fromJson(json.decode(response));
    if (kDebugMode) {
      debugPrint("""
      >>> Stop Record Response Output:  
      File: ${formatResponse.file} 
      Event Name: ${formatResponse.eventName}  
      Progressing: ${formatResponse.isProgress} 
      Message: ${formatResponse.message} 
      Success: ${formatResponse.success} 
      Video Hash: ${formatResponse.videoHash} 
      Start Date: ${formatResponse.startDate} 
      End Date: ${formatResponse.endDate}
      Check Status: ${formatResponse.checkStatus} // Thêm checkStatus
      """);
    }
    return formatResponse;
  }

  Future<bool> pauseRecord() async {
    return await _channel.invokeMethod('pauseRecordScreen');
  }

  Future<bool> resumeRecord() async {
    return await _channel.invokeMethod('resumeRecordScreen');
  }
}
