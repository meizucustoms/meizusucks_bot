import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:image/image.dart';
import 'package:teledart/model.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'global.dart';

List<String> bootloopy = [
  "ебейший апарат",
  "лучше горький бутлуп, чем сладкие баги",
  "суп с семи бутлупов",
  "бутлуп бутлупом вышибают",
  "готовь бутлуп летом, а баги зимой",
  "бутлуп никогда не приходит один...",
  "ни к селу, ни к бутлупу",
];

late BitmapFont obelix_8;
late BitmapFont obelix_24;
late BitmapFont obelix_36;
late BitmapFont obelix_48;

Future<void> initFonts() async {
  obelix_8 =
      BitmapFont.fromZip(await io.File("fonts/obelix8.zip").readAsBytes());
  obelix_24 =
      BitmapFont.fromZip(await io.File("fonts/obelix24.zip").readAsBytes());
  obelix_36 =
      BitmapFont.fromZip(await io.File("fonts/obelix36.zip").readAsBytes());
  obelix_48 =
      BitmapFont.fromZip(await io.File("fonts/obelix48.zip").readAsBytes());
}

int getSymbolWidth(BitmapFont font, String symbol) {
  int codeUnits = symbol.codeUnits[0];

  if (font.characters[codeUnits] == null) {
    return font.base ~/ 2;
  }

  return font.characters[codeUnits]!.width;
}

Future<Image> multidirectionalImageWaveTransform(
    double intensity, Image img) async {
  final image = img.clone();
  final imageX = image.clone();
  for (var i = 0; i < image.height; i++) {
    for (var j = 0; j < image.width; j++) {
      final offsetX = intensity * sin(2 * 3.14 * i / 150);
      final offsetY = intensity * cos(2 * 3.14 * j / 150);

      final jx = (j + offsetX.toInt()) % image.width;
      final ix = (i + offsetY.toInt()) % image.height;
      if (j + offsetX < image.width && i + offsetY < image.height) {
        image.setPixel(
          jx,
          i,
          imageX.getPixel(j, ix),
        );
      }
    }
  }
  return image;
}

Future<Image> multidirectionalImageFluidTransform(
    double intensity, Image img) async {
  final image = img.clone();
  final imageX = image.clone();
  for (var i = 0; i < image.height; i++) {
    for (var j = 0; j < image.width; j++) {
      final offsetX = intensity * sin(2 * i / 300);
      final offsetY = intensity * cos(2 * j / 150);

      final jx = (j + offsetX.toInt()) % image.width;
      final ix = (i + offsetY.toInt()) % image.height;
      if (j + offsetX < image.width && i + offsetY < image.height) {
        image.setPixel(
          jx,
          i,
          imageX.getPixel(j, ix),
        );
      }
    }
  }
  return image;
}

Future<Image?> getImageFromMessage(TeleDartMessage message) async {
  Message msg = message;

  if (message.document == null && message.photo == null) {
    if (message.reply_to_message == null ||
        (message.reply_to_message!.photo == null &&
            message.reply_to_message!.document == null &&
            message.reply_to_message!.sticker == null)) {
      tg.teledart.telegram.sendMessage(
          message.chat.id, "Отправьте одно изображение вместе с этой командой.",
          reply_to_message_id: message.message_id);
      return null;
    } else {
      msg = message.reply_to_message!;
    }
  }

  String id = "";

  if (msg.document != null) {
    Document doc = msg.document!;
    id = doc.file_id;
  } else if (msg.photo != null) {
    // Get photo in the best size
    PhotoSize doc = msg.photo![msg.photo!.length - 1];
    id = doc.file_id;
  } else if (msg.sticker != null) {
    Sticker doc = msg.sticker!;
    id = doc.file_id;
  }

  File docFile = await tg.telegram.getFile(id);

  String? uri = docFile.getDownloadLink(MzConfig.botId);

  Uint8List? imageBytes;

  await http.get(Uri.parse(uri!)).then((response) {
    imageBytes = response.bodyBytes;
  });

  if (imageBytes == null) {
    tg.teledart.telegram.sendMessage(
        message.chat.id, "Ошибка получения данных изображения.",
        reply_to_message_id: message.message_id);
    return null;
  }

  Image? image = decodeImage(imageBytes!);
  if (image == null) {
    tg.teledart.telegram.sendMessage(
        message.chat.id, "Ошибка декодирования изображения.",
        reply_to_message_id: message.message_id);
    return null;
  }

  return image;
}

Future<bool> sendImage(TeleDartMessage targetMsg, Image image) async {
  io.File temp = io.File(
    "/tmp/tgbot_${Random().nextInt(2048).toString()}.png",
  );

  try {
    await temp.writeAsBytes(encodePng(image));

    await tg.telegram.sendPhoto(targetMsg.chat.id, temp,
        reply_to_message_id: targetMsg.message_id);

    await temp.delete();
  } catch (e) {
    await temp.delete();
    tg.teledart.telegram.sendMessage(
        targetMsg.chat.id, "Ошибка при отправке изображения.",
        reply_to_message_id: targetMsg.message_id);
    return true;
  }

  return false;
}

Future<void> imageEditorPlaceWord(TeleDartMessage message) async {
  String phrase = bootloopy[Random().nextInt(bootloopy.length - 1)];

  Image? image = await getImageFromMessage(message);
  if (image == null) {
    return;
  }

  if (message.text != null &&
      message.text!.replaceAll("/cringeimg_word ", "").isNotEmpty &&
      message.text!.replaceAll("/cringeimg_word", "").isNotEmpty) {
    phrase = message.text!.replaceAll("/cringeimg_word ", "");
  }

  late BitmapFont font;
  int letterSize = 0;

  if (image.width < 200) {
    font = obelix_8;
    letterSize = 8;
  } else if (image.width < 500) {
    font = obelix_24;
    letterSize = 24;
  } else if (image.width < 700) {
    font = obelix_36;
    letterSize = 36;
  } else {
    font = obelix_48;
    letterSize = 48;
  }

  int pharseSize = phrase.length;
  int lineSize = letterSize == 8 ? 2 : 20;
  int padding = letterSize == 8 ? 20 : 100;

  for (int i = 0; i < pharseSize; i++) {
    int symbolSize = getSymbolWidth(font, phrase.substring(i, i + 1));

    if (lineSize + symbolSize > image.width) {
      if (phrase.substring(i, i + 1) != ' ' &&
          phrase.substring(i - 1, i) != ' ') {
        phrase =
            phrase.substring(0, i) + "-\n" + phrase.substring(i, phrase.length);
      }

      if (phrase.substring(i, i + 1) == ' ') {
        phrase = phrase.substring(0, i) +
            "\n" +
            phrase.substring(i + 1, phrase.length);
      }

      if (phrase.substring(i - 1, i) == ' ') {
        phrase =
            phrase.substring(0, i) + "\n" + phrase.substring(i, phrase.length);
      }

      lineSize = letterSize == 8 ? 2 : 20;
      padding += (letterSize + 2);
      i++;
      continue;
    }

    lineSize += symbolSize;
  }

  if (padding > (letterSize == 8 ? 20 : 100)) {
    List<String> split = phrase.split("\n");

    for (int i = 0; i < split.length; i++) {
      drawString(
        image,
        font,
        letterSize == 8 ? 2 : 20,
        (image.height - padding) + ((i + 1) * (letterSize + 2)),
        split[i],
      );
    }
  } else {
    drawString(
      image,
      font,
      letterSize == 8 ? 2 : 20,
      image.height - padding,
      phrase,
    );
  }

  await sendImage(message, image);
}

Future<void> imageEditorDownUpScale(
    TeleDartMessage message, bool pixelate) async {
  Image? image = await getImageFromMessage(message);
  if (image == null) {
    return;
  }

  int initialWidth = image.width;
  int scale = 2;

  if (message.text != (pixelate ? "/cringeimg_res_pix" : "/cringeimg_res")) {
    int? t = int.tryParse(message.text!.replaceAll(
        "${(pixelate ? "/cringeimg_res_pix" : "/cringeimg_res")} ", ""));
    if (t != null && t > 0) {
      scale = t;
    }
  }

  print((initialWidth / scale).toString());

  if ((initialWidth / scale) < 1) {
    tg.teledart.telegram.sendMessage(
        message.chat.id, "Слишком большой уровень уменьшения",
        reply_to_message_id: message.message_id);
    return;
  }

  image = copyResize(image,
      width: initialWidth ~/ scale,
      interpolation: pixelate ? Interpolation.nearest : Interpolation.cubic);
  image = copyResize(image,
      width: initialWidth,
      interpolation: pixelate ? Interpolation.nearest : Interpolation.cubic);

  await sendImage(message, image);
}

Future<void> imageEditorFunnyScale(TeleDartMessage message) async {
  Image? image = await getImageFromMessage(message);
  if (image == null) {
    return;
  }

  int scale = 5;

  if (message.text != "/cringeimg_scale") {
    int? t = int.tryParse(message.text!.replaceAll("/cringeimg_scale ", ""));
    if (t != null && t > 0) {
      scale = t;
    }
  }

  image = copyResize(
    image,
    width: image.width,
    height: image.height ~/ scale,
    interpolation: Interpolation.cubic,
  );

  await sendImage(message, image);
}

Future<void> imageEditorDistortion1(TeleDartMessage message) async {
  Image? image = await getImageFromMessage(message);
  if (image == null) {
    return;
  }

  int scale = 5;

  if (message.text != "/cringeimg_dst1") {
    int? t = int.tryParse(message.text!.replaceAll("/cringeimg_dst1 ", ""));
    if (t != null && t > 0) {
      scale = t;
    }
  }

  image = await multidirectionalImageWaveTransform(scale / 10, image);

  await sendImage(message, image);
}

Future<void> imageEditorDistortion2(TeleDartMessage message) async {
  Image? image = await getImageFromMessage(message);
  if (image == null) {
    return;
  }

  int scale = 5;

  if (message.text != "/cringeimg_dst2") {
    int? t = int.tryParse(message.text!.replaceAll("/cringeimg_dst2 ", ""));
    if (t != null && t > 0) {
      scale = t;
    }
  }

  image = await multidirectionalImageFluidTransform(scale / 10, image);

  await sendImage(message, image);
}

Future<void> setupImageCallbacks() async {
  await initFonts();

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_word")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorPlaceWord(message);
    }
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_res")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorDownUpScale(message, false);
    }
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_res_pix")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorDownUpScale(message, true);
    }
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_scale")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorFunnyScale(message);
    }
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_dst1")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorDistortion1(message);
    }
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "cringeimg_dst2")
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      await imageEditorDistortion2(message);
    }
  });
}
