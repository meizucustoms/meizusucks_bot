import 'dart:io';

import 'package:process_run/shell.dart';

import 'config.dart';
import 'global.dart';

//
// NOT WORKING NOW
//

void main(List<String> arguments) async {
  var shell = Shell(runInShell: true);

  String target = arguments[1];

  // Get settings
  if (!await MzConfig.parseJSON()) {
    print("Failed to get settings.");
    return;
  }

  print("Build type: ${MzConfig.buildType.toString()}");

  await tg.setup();

  DateTime oldDate = DateTime.now();

  print("Preparing build environment...");
  tg.sendTestersMessage("Начата сборка $target в ${oldDate.toString()}");

  shell.cd(MzConfig.buildDir);

  List<ProcessResult> result = await shell.run('''
/bin/zsh -c "
source build/envsetup.sh && \\
export USE_CCACHE=true && \\
lunch lineage_m1721-${MzConfig.buildType.toString().replaceAll("MzConfig.", "")} && \\
make $target -j4
"
  ''');

  DateTime newDate = DateTime.now();

  if (result[0].exitCode != 0) {
    tg.sendTestersMessage(
        "Сборка ${target}, начатая в ${oldDate.toString()}, ПРОВАЛИЛАСЬ в ${newDate.toString()}.");
  } else {
    tg.sendTestersMessage(
        "Сборка ${target}, начатая в ${oldDate.toString()}, БЫЛА ЗАВЕРШЕНА УСПЕШНО в ${newDate.toString()}.");
  }
}
