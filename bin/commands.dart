import 'dart:async';
import 'dart:math';

import 'package:teledart/model.dart';

import 'config.dart';
import 'game.dart';
import 'global.dart';
import 'images.dart';
import 'ioctl.dart';
import 'dart:io' as io;

List<int> banList = [];

bool isMessageBlocked(Message msg, bool onlyTestersChat) {
  int userId = msg.from!.id;
  if (banList.contains(userId)) {
    print("User ${userId.toString()} banned");
    return true;
  }

  if (onlyTestersChat &&
      msg.chat.id != MzConfig.testersChat &&
      msg.chat.id != 716078470) {
    print(
        "Request with chat id ${msg.chat.id.toString()} blocked (onlyTesters)");
    return true;
  }

  if (msg.chat.id != MzConfig.basicChat &&
      msg.chat.id != MzConfig.testersChat &&
      msg.chat.id != 716078470) {
    print("Request with chat id ${msg.chat.id.toString()} blocked (nonMsChat)");
    return true;
  }

  return false;
}

void showHelp(TeleDartMessage message) {
  if (message.chat.id != MzConfig.testersChat) {
    tg.teledart.telegram.sendMessage(
        message.chat.id,
        "Умею:\n"
                "/imgtxt 'опционально: текст': добавить фразу к картинке крутым шрифтом!\n"
                "/imgscl 'опционально: степень': сжать картинку по высоте\n"
                "/imgshk 'опционально: степень': сжать картинку по разрешению и снова ее вернуть к нормальному разрешению\n"
                "/imgpix 'опционально: степень': /imgshk но более пиксельно\n"
                "/imgdst1 'опционально: степень': деформация изображения 'волнами' по оси X и Y\n"
                "/imgdst2 'опционально: степень': деформация изображения по страшной формуле но смешно\n"
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
              "/imgtxt 'опционально: текст': добавить фразу к картинке крутым шрифтом!\n"
              "/imgscl 'опционально: степень': сжать картинку по высоте\n"
              "/imgshk 'опционально: степень': сжать картинку по разрешению и снова ее вернуть к нормальному разрешению\n"
              "/imgpix 'опционально: степень': /imgshk но более пиксельно\n"
              "/imgdst1 'опционально: степень': деформация изображения 'волнами' по оси X и Y\n"
              "/imgdst2 'опционально: степень': деформация изображения по страшной формуле но смешно\n"
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
    if (isMessageBlocked(message, false)) {
      return;
    }

    tg.teledart.telegram.sendMessage(message.chat.id, 'Я могу только /stop.',
        reply_to_message_id: message.message_id);
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'bootloop')
      .listen((message) async {
    if (isMessageBlocked(message, false)) {
      return;
    }

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
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'stop')
      .listen((message) {
    if (isMessageBlocked(message, false)) {
      return;
    }

    tg.teledart.telegram.sendMessage(message.chat.id, 'Я могу только /start.',
        reply_to_message_id: message.message_id);
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'help')
      .listen((message) {
    if (isMessageBlocked(message, false)) {
      return;
    }
    showHelp(message);
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'mzhelp')
      .listen((message) {
    if (isMessageBlocked(message, false)) {
      return;
    }
    showHelp(message);
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'hey')
      .listen((message) async {
    if (isMessageBlocked(message, true)) {
      return;
    }

    if (message.from!.username != "tdrkDev") {
      return;
    }

    if ((await getPtsPath()).isEmpty) {
      tg.teledart.telegram.sendMessage(
          message.chat.id, "Ни одна сессия zsh не прикреплена к боту.",
          reply_to_message_id: message.message_id);
      return;
    }

    VirtTerminal terminal = VirtTerminal(await getPtsPath());

    tg.teledart.telegram.sendMessage(message.chat.id, "Выполняю команду...",
        reply_to_message_id: message.message_id);

    await Future.delayed(Duration(milliseconds: 50));

    terminal.executeCmd(message.text!.replaceAll("/hey ", ""));

    await Future.delayed(Duration(milliseconds: 10));

    var log = io.File("/home/tdrk/.msucks_last_cmd.log");
    var stream = log.watch();

    String oldLog = "";
    late StreamSubscription<io.FileSystemEvent> sub;

    sub = stream.listen((event) async {
      String curlog = await log.readAsString();

      curlog = curlog.replaceAll(oldLog, "");
      oldLog = oldLog + curlog;

      if (curlog.contains("mzCallbackCmdCompletion")) {
        await sub.cancel();

        tg.telegram.sendDocument(
            message.chat.id, io.File("/home/tdrk/.msucks_last_cmd.log"));

        return;
      }

      if (curlog.isEmpty) {
        return;
      }
    });
  });

  tg.teledart
      .onMessage(entityType: 'bot_command', keyword: 'last_build')
      .listen((message) async {
    if (isMessageBlocked(message, true)) {
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
    } else if (info.link == "uploading") {
      link = "*Скачать*: сборка заливается";
    } else {
      link = "*Скачать*: [Google Drive](${info.link})";
    }

    date = date.replaceAll("_", "\\_");
    type = type.replaceAll("_", "\\_");

    String fullMsg = (date + "\n" + type + "\n" + succeed + "\n" + link);

    tg.teledart.telegram.sendMessage(message.chat.id, fullMsg,
        parse_mode: "Markdown", reply_to_message_id: message.message_id);
  });

  await setupImageCallbacks();
  await setupGameCallbacks();
}
