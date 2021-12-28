if [ ! -z "$1" ] && [ "$1" = "build" ]; then
    dart run bin/build.dart $@
else
    sudo $HOME/flutter/bin/dart run bin/commands.dart
fi
