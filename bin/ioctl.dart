// ignore_for_file: constant_identifier_names, camel_case_types

import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:utf_convert/utf_convert.dart';
import 'dart:io';

import 'global.dart';

const TIOCSTI = 0x5412;
const O_RDWR = 02;

Future<String> getPtsPath() async {
  String? pid = await readStringFromFile("/home/tdrk/.msucks_shell_pid");
  if (pid == null) {
    return "";
  }

  pid = pid.replaceAll("\n", "");

  String proc = "/proc/" + pid + "/fd/0";
  String pts;

  try {
    pts = File(proc).resolveSymbolicLinksSync();
  } catch (e) {
    pts = "";
  }

  return pts;
}

// int ioctl(int, unsigned long, ...);
typedef ioctlNative = Int32 Function(Int32, Int64, Pointer<Uint8>);
typedef ioctlDart = int Function(int, int, Pointer<Uint8>);

// int open(const char *pathname, int flags);
typedef openNative = Int32 Function(Pointer<Utf8>, Int32);
typedef openDart = int Function(Pointer<Utf8>, int);

// int close(int fd);
typedef closeNative = Int32 Function(Int32);
typedef closeDart = int Function(int);

extension on String {
  void forEverySymbol(Function(String symbol) handler) {
    for (int i = 0; i < length; i++) {
      handler(substring(i, i + 1));
    }
  }
}

extension on List<int?> {
  List<int> toListInt() {
    List<int> ret = [];

    for (int i = 0; i < length; i++) {
      ret.add(elementAt(i) ?? 0);
    }

    return ret;
  }
}

class VirtTerminal {
  late final ioctlDart _ioctl;
  late final openDart _open;
  late final closeDart _close;
  late final String _pts;

  void executeCmd(String cmd) {
    int fd = _open(_pts.toNativeUtf8(), O_RDWR);
    if (fd < 0) {
      print("Failed to open $_pts: ${fd.toString()}");
      return;
    }

    print("fd: ${fd.toString()}");

    cmd.forEverySymbol((symbol) {
      List<int> char = encodeUtf8(symbol).toListInt();
      Pointer<Uint8> cchar = symbol.toNativeUtf8().cast<Uint8>();

      for (int i = 0; i < char.length; i++) {
        _ioctl(fd, TIOCSTI, Pointer.fromAddress(cchar.address + i));
      }

      calloc.free(cchar);
    });

    String additionalCmd =
        ' | tee \$HOME/.msucks_last_cmd.log && echo -e "mzCallbackCmdCompletion" >> \$HOME/.msucks_last_cmd.log';

    additionalCmd.forEverySymbol((symbol) {
      List<int> char = utf8.encode(symbol);
      Pointer<Uint8> cchar = symbol.toNativeUtf8().cast<Uint8>();

      for (int i = 0; i < char.length; i++) {
        _ioctl(fd, TIOCSTI, Pointer.fromAddress(cchar.address + i));
      }

      calloc.free(cchar);
    });

    Pointer<Uint8> char = "\n".toNativeUtf8().cast<Uint8>();

    _ioctl(fd, TIOCSTI, char);

    calloc.free(char);

    int ret = _close(fd);
    if (ret < 0) {
      print("Failed to close $_pts, fd ${fd.toString()}: ${ret.toString()}");
      return;
    }

    print("Done executing $cmd.");
  }

  VirtTerminal(String pts) {
    final libc = DynamicLibrary.open('libc.so.6');
    _ioctl = libc.lookupFunction<ioctlNative, ioctlDart>('ioctl');
    _open = libc.lookupFunction<openNative, openDart>('open');
    _close = libc.lookupFunction<closeNative, closeDart>('close');
    _pts = pts;
  }
}

void executeCmd(String cmd) async {
  VirtTerminal terminal = VirtTerminal(await getPtsPath());
  terminal.executeCmd(cmd);
}
