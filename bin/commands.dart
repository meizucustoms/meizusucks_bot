import 'dart:math';

import 'package:teledart/model.dart';

import 'config.dart';
import 'global.dart';
import 'images.dart';

void showHelp(TeleDartMessage message) {
  if (message.chat.id != MzConfig.testersChat) {
    tg.teledart.telegram.sendMessage(
        message.chat.id,
        "Умею:\n"
                "/cringeimg_word 'опционально: текст': добавить фразу к картинке крутым шрифтом!\n"
                "/cringeimg_scale 'опционально: степень': сжать картинку по высоте\n"
                "/cringeimg_res 'опционально: степень': сжать картинку по разрешению и снова ее вернуть к нормальному разрешению\n"
                "/cringeimg_res_pix 'опционально: степень': /cringeimg_res но более пиксельно\n"
                "/cringeimg_dst1 'опционально: степень': деформация изображения 'волнами' по оси X и Y\n"
                "/cringeimg_dst2 'опционально: степень': деформация изображения по страшной формуле но смешно\n"
                "/start|/stop: кринж #1\n"
                "/bootloop: кринж #2\n\n"
                "`Говнокод by tdrkDev (c) 2021`"
            .replaceAll("_", "\\_"),
        reply_to_message_id: message.message_id,
        parse_mode: "Markdown");
    return;
  }

  tg.teledart.telegram.sendMessage(
      message.chat.id,
      "Умею:\n"
              "/cringeimg_word 'опционально: текст': добавить фразу к картинке крутым шрифтом!\n"
              "/cringeimg_scale 'опционально: степень': сжать картинку по высоте\n"
              "/cringeimg_res 'опционально: степень': сжать картинку по разрешению и снова ее вернуть к нормальному разрешению\n"
              "/cringeimg_res_pix 'опционально: степень': /cringeimg_res но более пиксельно\n"
              "/cringeimg_dst1 'опционально: степень': деформация изображения 'волнами' по оси X и Y\n"
              "/cringeimg_dst2 'опционально: степень': деформация изображения по страшной формуле но смешно\n"
              "/start|/stop: кринж #1\n"
              "/bootloop: кринж #2\n"
              "/last_build: статус, дата, ссылка на последнюю сборку\n\n"
              "`Говнокод by tdrkDev (c) 2021`"
          .replaceAll("_", "\\_"),
      reply_to_message_id: message.message_id,
      parse_mode: "Markdown");
}

void main(List<String> arguments) async {
  // Get settings
  if (!await MzConfig.parseJSON()) {
    print("Failed to get settings.");
    return;
  }

  await tg.setup();

  tg.teledart.start();

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'start')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      tg.teledart.telegram.sendMessage(message.chat.id, 'Я могу только /stop.',
          reply_to_message_id: message.message_id);
    }
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'bootloop')
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      StickerSet mSucksStickers = await tg.teledart.telegram
          .getStickerSet("ghbtuszdv_1001428227417_by_QuotLyBot");

      tg.teledart.telegram.sendSticker(
          message.chat.id,
          mSucksStickers
              .stickers[message.chat.id != MzConfig.testersChat
                  ? Random().nextInt(mSucksStickers.stickers.length)
                  : 32]
              .file_id,
          reply_to_message_id: message.message_id);
    }
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'stop')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      tg.teledart.telegram.sendMessage(message.chat.id, 'Я могу только /start.',
          reply_to_message_id: message.message_id);
    }
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'help')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      showHelp(message);
    }
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'mzhelp')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      showHelp(message);
    }
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'last_build')
      .listen((message) async {
    if (message.chat.id != MzConfig.testersChat &&
        message.chat.id == MzConfig.basicChat) {
      tg.teledart.telegram.sendMessage(
          message.chat.id, 'Данная команда запрещена не для тестеров.',
          reply_to_message_id: message.message_id);
      return;
    }

    MzBuildInfo info = await readBuildInfo();

    String succeed, date, link, type;

    if (info.succeed == null) {
      succeed = "*Статус*: идет сборка";
    } else {
      succeed = "*Статус*: " + (info.succeed! ? "успех" : "пипец");
    }

    if (info.type == null) {
      type = "*Тип*: неизвестно";
    } else {
      type = "*Тип*: ${info.type}";
    }

    if (info.date == null) {
      date = "*Дата сборки*: неизвестно";
    } else {
      date = "*Дата сборки*: ${info.date.toString()}";
    }

    if (info.link == null) {
      link = "*Скачать*: ссылка не приложена";
    } else {
      link = "*Скачать*: [Sourceforge](${info.link})";
    }

    date = date.replaceAll("_", "\\_");
    type = type.replaceAll("_", "\\_");

    String fullMsg = (date + "\n" + type + "\n" + succeed + "\n" + link);

    tg.teledart.telegram
        .sendMessage(message.chat.id, fullMsg, parse_mode: "Markdown");
  });

  await setupImageCallbacks();
}
