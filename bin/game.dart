import 'dart:convert';
import 'dart:math';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:teledart/model.dart';
import 'commands.dart';
import 'config.dart';
import 'global.dart';
import 'package:function_tree/function_tree.dart';

bool testingMode = false;
late Database gameDb;
late DateTime midnightEvent;

Future<void> setupGameDatabase() async {
  sqfliteFfiInit();

  gameDb = await databaseFactoryFfi.openDatabase(
    "/home/tdrk/mzbotgame.db",
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) {
        db.execute(
            'CREATE TABLE players(uid INTEGER PRIMARY KEY, commitsLeft INTEGER, commits INTEGER, joinDate INTEGER, task TEXT)');
      },
    ),
  );
}

enum TaskStepAction {
  plus,
  minus,
  multiplication,
}

extension on TaskStepAction {
  String get string {
    switch (this) {
      case TaskStepAction.plus:
        return '+';
      case TaskStepAction.minus:
        return '-';
      case TaskStepAction.multiplication:
        return '*';
    }
  }
}

TaskStepAction actFromInt(int num) {
  switch (num) {
    case 0:
      return TaskStepAction.multiplication;
    case 1:
      return TaskStepAction.minus;
    default:
      return TaskStepAction.plus;
  }
}

TaskStepAction actFromStr(String str) {
  switch (str) {
    case "*":
      return TaskStepAction.multiplication;
    case "-":
      return TaskStepAction.minus;
    default:
      return TaskStepAction.plus;
  }
}

class TaskStep {
  late int number;
  late TaskStepAction action;

  TaskStep.random() {
    number = Random().nextInt(256);
    action = actFromInt(Random().nextInt(4));
  }

  Map<String, dynamic> toMap() {
    return {
      "number": number,
      "action": action.string,
    };
  }

  TaskStep.fromMap(Map<String, dynamic> map) {
    number = map["number"];
    action = actFromStr(map["action"]);
  }

  TaskStep(this.number, this.action);
}

class PlayerTask {
  late List<TaskStep> steps;
  late int baseNumber;

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> jsonSteps = [];

    for (var i in steps) {
      jsonSteps.add(i.toMap());
    }

    return {
      "baseNumber": baseNumber,
      "steps": jsonSteps,
    };
  }

  PlayerTask.fromMap(Map<String, dynamic> map) {
    baseNumber = map["baseNumber"];
    steps = [];

    for (Map<String, dynamic> i
        in List<Map<String, dynamic>>.from(map["steps"])) {
      steps.add(TaskStep.fromMap(i));
    }
  }

  @override
  String toString() {
    String ret = baseNumber.toString();

    for (var i in steps) {
      ret += " ${i.action.string} ${i.number.toString()}";
    }

    return ret;
  }

  int solve() {
    return toString().interpret().toInt();
  }

  PlayerTask() {
    steps = [];
    baseNumber = Random().nextInt(256);

    int totalSteps = 0;

    while (totalSteps < 2) {
      totalSteps = Random().nextInt(5);
    }

    for (int i = 0; i < totalSteps; i++) {
      steps.add(TaskStep.random());
    }
  }
}

class GamePlayer {
  late int uid;
  late int commitsLeft;
  late int commits;
  late int joinDate;
  late PlayerTask? task;

  GamePlayer({
    this.uid = 0,
    this.commits = 0,
    this.commitsLeft = -1,
    this.joinDate = 0,
    this.task,
  });

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "commitsLeft": commitsLeft,
      "commits": commits,
      "joinDate": joinDate,
      "task": task != null ? jsonEncode(task!.toMap()) : "none",
    };
  }

  GamePlayer.fromMap(Map<String, dynamic> map) {
    uid = map["uid"];
    commitsLeft = map["commitsLeft"];
    commits = map["commits"];
    joinDate = map["joinDate"];
    task = (map["task"] != "none")
        ? PlayerTask.fromMap(jsonDecode(map["task"]))
        : null;
  }
}

Future<GamePlayer?> locatePlayer(int uid) async {
  List<Map<String, dynamic>> players = await gameDb.query(
    "players",
    where: "uid = ?",
    whereArgs: [uid],
  );

  if (players.isEmpty || players[0].isEmpty) {
    return null;
  }

  return GamePlayer.fromMap(players[0]);
}

Future<void> deletePlayer(int uid) async {
  await gameDb.delete(
    "players",
    where: "uid = ?",
    whereArgs: [uid],
  );
}

Future<void> createPlayer(GamePlayer player) async {
  await gameDb.insert(
    "players",
    player.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updatePlayer(GamePlayer player) async {
  await gameDb.update(
    "players",
    player.toMap(),
    where: "uid = ?",
    whereArgs: [player.uid],
  );
}

Future<void> fixBug(TeleDartMessage message) async {
  String username = message.from != null
      ? (message.from!.username ?? message.from!.first_name)
      : "error";

  if (message.from == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Пользователь не найден (message.from == NULL) (TELEGRAM API ERROR)",
        reply_to_message_id: message.message_id);
  }

  GamePlayer? player = await locatePlayer(message.from!.id);
  if (player == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Вы еще не начали игру. Станьте разработчиком - /become_developer!",
        reply_to_message_id: message.message_id);
    return;
  }

  if (player.task != null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Для нового коммита необходимо сначала доделать старый.",
        reply_to_message_id: message.message_id);
    return;
  }

  if (player.commitsLeft == 0) {
    await tg.telegram.sendMessage(message.chat.id,
        "Вы уже выполнили свою норму по фиксам багов на сегодня.",
        reply_to_message_id: message.message_id);
    return;
  }

  player.task = PlayerTask();
  updatePlayer(player);

  PlayerTask task = player.task!;

  await tg.telegram.sendMessage(message.chat.id,
      "Похоже, что компьютер ошибся с математикой. Решите пример ${task.toString()} за 30 секунд (дедлайны поджимают!)",
      reply_to_message_id: message.message_id);

  Future.delayed(Duration(seconds: 30)).then((_) async {
    GamePlayer? plr = await locatePlayer(player.uid);
    if (plr == null) return;

    if (plr.task != null) {
      await tg.telegram.sendMessage(message.chat.id, "Время вышло!",
          reply_to_message_id: message.message_id);
      removeDeveloperInternal(plr);
    }
  });
}

Future<void> endBugFix(TeleDartMessage message, GamePlayer player) async {
  if (message.from == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Пользователь не найден (message.from == NULL) (TELEGRAM API ERROR)",
        reply_to_message_id: message.message_id);
  }

  int? answer = int.tryParse(message.text ?? "error");
  if (answer == null) {
    await tg.telegram.sendMessage(
        message.chat.id, "Не удалось найти в тексте сообщения число",
        reply_to_message_id: message.message_id);
    return;
  }

  if (message.from == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Пользователь не найден (message.from == NULL) (TELEGRAM API ERROR)",
        reply_to_message_id: message.message_id);
  }

  int rightAnswer = player.task!.solve();

  if (rightAnswer != answer) {
    await tg.telegram.sendMessage(
        message.chat.id, "Ответ неверный! Направляем вас в Flyme Dev Team...",
        reply_to_message_id: message.message_id);
    await removeDeveloper(message);
    return;
  }

  await tg.telegram.sendMessage(
      message.chat.id, "Ответ верный! Добавляем один коммит на ваш счёт :)",
      reply_to_message_id: message.message_id);

  player.task = null;
  player.commits++;
  player.commitsLeft--;

  updatePlayer(player);
}

Future<void> removeDeveloper(TeleDartMessage message) async {
  if (message.from == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Пользователь не найден (message.from == NULL) (TELEGRAM API ERROR)",
        reply_to_message_id: message.message_id);
  }

  String username = message.from != null
      ? (message.from!.username ?? message.from!.first_name)
      : "error";

  GamePlayer? player = await locatePlayer(message.from!.id);
  if (player == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Вы еще не начали игру. Станьте разработчиком - /become_developer!",
        reply_to_message_id: message.message_id);
    return;
  }

  deletePlayer(player.uid);

  await tg.telegram.sendMessage(message.chat.id,
      "$username, мы вас поздравляем, вас приняли в Flyme Dev Team! Индусы изъяли все ваши коммиты с GitHub для их переноса в Flyme. Удачи. (GAME OVER)",
      reply_to_message_id: message.message_id);
}

Future<void> getPlayerStats(TeleDartMessage message) async {
  if (message.from == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Пользователь не найден (message.from == NULL) (TELEGRAM API ERROR)",
        reply_to_message_id: message.message_id);
  }

  GamePlayer? player = await locatePlayer(message.from!.id);
  if (player == null) {
    await tg.telegram.sendMessage(message.chat.id,
        "Вы еще не начали игру. Станьте разработчиком - /become_developer!",
        reply_to_message_id: message.message_id);
    return;
  }

  await tg.telegram.sendMessage(message.chat.id,
      "Коммиты: ${player.commits}\nОсталось выполнить на сегодня фиксов: ${player.commitsLeft}",
      reply_to_message_id: message.message_id);
}

Future<void> removeDeveloperInternal(GamePlayer player) async {
  User user = (await tg.telegram.getChatMember(
          testingMode ? MzConfig.testersChat : MzConfig.basicChat, player.uid))
      .user;

  String username = (user.username ?? user.first_name);

  deletePlayer(user.id);

  await tg.telegram.sendMessage(
      testingMode ? MzConfig.testersChat : MzConfig.basicChat,
      "$username, мы вас поздравляем, вас приняли в Flyme Dev Team! Индусы изъяли все ваши коммиты с GitHub для их переноса в Flyme. Удачи. (GAME OVER)",
      reply_to_message_id:
          testingMode ? MzConfig.testersChat : MzConfig.basicChat);
}

Future<void> createNewDeveloper(TeleDartMessage message) async {
  String username = message.from != null
      ? (message.from!.username ?? message.from!.first_name)
      : "error";

  GamePlayer? player = await locatePlayer(message.from!.id);
  if (player != null) {
    await tg.telegram.sendMessage(message.chat.id, "Вы и так уже начали игру.",
        reply_to_message_id: message.message_id);
    return;
  }

  createPlayer(
    GamePlayer(
      uid: message.from!.id,
      commitsLeft: 2,
      joinDate: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  await tg.telegram.sendMessage(message.chat.id,
      "Добро пожаловать в игру, $username! Каждый день необходимо будет выполнять норму в 2 коммита. Иногда будут проходить сходки Open-Source разработчиков. Коммит делается командой /bugfix. Начнайте работать!",
      reply_to_message_id: message.message_id);
}

int holdSeconds = 180;

void processMidnightEvent() async {
  await tg.telegram.sendMessage(
      testingMode ? MzConfig.testersChat : MzConfig.basicChat,
      "Началась чистка ленивых...");

  final rawPlayers = await gameDb.query("players", where: "commitsLeft <> 0");
  for (var i in rawPlayers) {
    removeDeveloperInternal(GamePlayer.fromMap(i));
  }
}

void waitTillMidnightEvent() async {
  while (true) {
    if (DateTime.now().millisecondsSinceEpoch >
        midnightEvent.millisecondsSinceEpoch) {
      midnightEvent = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      processMidnightEvent();
    }

    // Optimization???
    if (DateTime.now().millisecondsSinceEpoch + 180 * 1000 >=
        midnightEvent.millisecondsSinceEpoch) {
      holdSeconds = 10;
    } else if (DateTime.now().millisecondsSinceEpoch + 10 * 1000 >=
        midnightEvent.millisecondsSinceEpoch) {
      holdSeconds = 1;
    } else if (holdSeconds != 180) {
      holdSeconds = 180;
    }

    await Future.delayed(Duration(seconds: holdSeconds));
  }
}

void setupEvents() async {
  DateTime now = DateTime.now();
  midnightEvent = DateTime(now.year, now.month, now.day);
}

Future<void> setupGameCallbacks() async {
  await setupGameDatabase();

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "stats")
      .listen((message) async {
    if (isMessageBlocked(message, testingMode)) {
      return;
    }

    await getPlayerStats(message);
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "become_developer")
      .listen((message) async {
    if (isMessageBlocked(message, testingMode)) {
      return;
    }

    await createNewDeveloper(message);
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "become_flyme_developer")
      .listen((message) async {
    if (isMessageBlocked(message, testingMode)) {
      return;
    }

    await removeDeveloper(message);
  });

  tg.teledart
      .onMessage(entityType: "bot_command", keyword: "bugfix")
      .listen((message) async {
    if (isMessageBlocked(message, testingMode)) {
      return;
    }

    await fixBug(message);
  });

  tg.teledart.onMessage().listen((message) async {
    if (isMessageBlocked(message, testingMode)) {
      return;
    }

    GamePlayer? player = await locatePlayer(message.from!.id);
    if (player == null || player.task == null) {
      return;
    }

    await endBugFix(message, player);
  });

  setupEvents();
}
