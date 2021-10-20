if [ ! -z "$1" ] && [ "$1" = "build" ]; then
    dart run bin/build.dart $@
else
    dart run bin/commands.dart &
fi