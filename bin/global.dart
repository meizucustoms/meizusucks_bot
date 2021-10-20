import "dart:io";

import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

import 'config.dart';

class MzBuildInfo {
  bool? succeed;
  DateTime? date;
  String? link;
  String? type;

  MzBuildInfo({this.succeed, this.date, this.link, this.type});
}

class MzTg {
  late TeleDart teledart;
  late Event event;
  late Telegram telegram;

  Future<MzTg> setup() async {
    telegram = Telegram(MzConfig.botId);
    event = Event((await telegram.getMe()).username!);
    teledart = TeleDart(telegram, event);

    return this;
  }

  void sendTestersMessage(String text, {bool markdown = false}) async {
    await teledart.telegram.sendMessage(
      MzConfig.testersChat,
      text,
      parse_mode: markdown ? "Markdown" : null,
    );
  }
}

MzTg tg = MzTg();

Future<String?> readStringFromFile(String path) async {
  File file = File(path);

  if (!await file.exists()) {
    return null;
  }

  file.open();

  String result = await file.readAsString();

  if (result.isEmpty) {
    return null;
  }

  return result;
}

Future<MzBuildInfo> readBuildInfo() async {
  MzBuildInfo result = MzBuildInfo();

  String? succeed =
      await readStringFromFile("/home/tdrk/.msucks_last_build_status");
  String? date = await readStringFromFile("/home/tdrk/.msucks_last_build_date");
  String? type = await readStringFromFile("/home/tdrk/.msucks_last_build_type");
  String? link = await readStringFromFile("/home/tdrk/.msucks_last_build_uri");

  result.type = type;
  result.link = link;

  if (succeed != null) {
    result.succeed = succeed.contains("success");
  }

  if (date != null) {
    result.date = DateTime.fromMillisecondsSinceEpoch(int.parse(date) * 1000);
  }

  return result;
}
