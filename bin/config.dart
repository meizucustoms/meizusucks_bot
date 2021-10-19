import 'dart:convert';

import 'global.dart';

enum MzBuildType { eng, userdebug, user, error }

extension on MzBuildType {
  MzBuildType fromString(String str) {
    switch (str) {
      case "eng":
        return MzBuildType.eng;
      case "userdebug":
        return MzBuildType.userdebug;
      case "user":
        return MzBuildType.user;
      default:
        return MzBuildType.error;
    }
  }
}

class MzConfig {
  static int testersChat = 0;
  static int basicChat = -1001428227417;
  static MzBuildType buildType = MzBuildType.error;
  static String botId = "";
  static String buildDir = "";

  static Future<bool> parseJSON() async {
    String? json = await readStringFromFile("/home/tdrk/.msbuilder.json");
    if (json == null) {
      return false;
    }

    Map<String, dynamic> parsed = jsonDecode(json);
    if (parsed.isEmpty) {
      return false;
    }

    testersChat = parsed["testersChat"];
    buildType = MzBuildType.error.fromString(parsed["buildType"]);
    botId = parsed["botId"];
    buildDir = parsed["buildDir"];

    return true;
  }
}
