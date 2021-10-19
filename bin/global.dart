import "dart:io";

class MzBuildInfo {
  bool? succeed;
  DateTime? date;
  String? link;
  String? type;

  MzBuildInfo({this.succeed, this.date, this.link, this.type});
}

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
