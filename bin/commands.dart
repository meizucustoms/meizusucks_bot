import 'dart:math';

import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:teledart/model.dart';

import 'config.dart';
import 'global.dart';

void main(List<String> arguments) async {
  // Get settings
  if (!await MzConfig.parseJSON()) {
    print("Failed to get settings.");
    return;
  }

  var telegram = Telegram(MzConfig.botId);
  var event = Event((await telegram.getMe()).username!);
  var teledart = TeleDart(telegram, event);

  teledart.start();

  teledart
      .onMessage(entityType: 'bot_command', keyword: 'start')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      teledart.telegram.sendMessage(message.chat.id, 'Я могу только /stop.',
          reply_to_message_id: message.message_id);
    }
  });

  teledart.onMessage(entityType: 'bot_command', keyword: 'q').listen((message) {
    if (message.chat.id == MzConfig.testersChat) {
      teledart.telegram.sendMessage(message.chat.id,
          'Привет, меня зовут QuotLy! ой не тот текст, короче фиг тебе а не стикер, какашка 😝',
          reply_to_message_id: message.message_id);
    }
  });

  teledart
      .onMessage(entityType: 'bot_command', keyword: 'bootloop')
      .listen((message) async {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      StickerSet mSucksStickers = await teledart.telegram
          .getStickerSet("ghbtuszdv_1001428227417_by_QuotLyBot");

      teledart.telegram.sendSticker(
          message.chat.id,
          mSucksStickers
              .stickers[message.chat.id != MzConfig.testersChat
                  ? Random().nextInt(mSucksStickers.stickers.length)
                  : 32]
              .file_id,
          reply_to_message_id: message.message_id);
    }
  });

  teledart
      .onMessage(entityType: 'bot_command', keyword: 'stop')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      teledart.telegram.sendMessage(message.chat.id, 'Я могу только /start.',
          reply_to_message_id: message.message_id);
    }
  });

  teledart
      .onMessage(entityType: 'bot_command', keyword: 'help')
      .listen((message) {
    if (message.chat.id == MzConfig.testersChat ||
        message.chat.id == MzConfig.basicChat) {
      if (message.chat.id != MzConfig.testersChat) {
        teledart.telegram.sendMessage(
            message.chat.id,
            "Умею:\n"
            "/start|/stop: кринж #1\n"
            "/bootloop: кринж #2\n\n"
            "`Говнокод by tdrkDev (c) 2021`",
            reply_to_message_id: message.message_id,
            parse_mode: "Markdown");
        return;
      }

      teledart.telegram.sendMessage(
          message.chat.id,
          "Умею:\n"
          "/start|/stop: кринж #1\n"
          "/bootloop: кринж #2\n"
          "/last\\_build: статус, дата, ссылка на последнюю сборку\n\n"
          "`Говнокод by tdrkDev (c) 2021`",
          reply_to_message_id: message.message_id,
          parse_mode: "Markdown");
    }
  });

  teledart
      .onMessage(entityType: 'bot_command', keyword: 'last_build')
      .listen((message) async {
    if (message.chat.id != MzConfig.testersChat &&
        message.chat.id == MzConfig.basicChat) {
      teledart.telegram.sendMessage(
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

    teledart.telegram
        .sendMessage(message.chat.id, fullMsg, parse_mode: "Markdown");
  });
}
