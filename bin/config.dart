import 'dart:convert';

import 'global.dart';

enum MzBuildType { eng, userdebug, user, error }

class MzConfig {
  static int testersChat = 0;
  static int basicChat = -1001428227417;
  static MzBuildType buildType = MzBuildType.error;
  static String botId = "";
  static String buildDir = "";

  static Future<void> parseJSON() async {
    String? json = await readStringFromFile("/home/tdrk/.mzbuilder.json");
    if (json == null) {
      return;
    }

    Map<String, dynamic> parsed = jsonDecode(json);
    if (parsed.isEmpty) {
      return;
    }

    testersChat = parsed["testersChat"];
    buildType = parsed["buildType"];
    botId = parsed["botId"];
    buildDir = parsed["buildDir"];
  }
}
