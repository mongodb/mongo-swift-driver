#!/bin/sh

case "$(uname -s)" in
    Darwin)
        sed=gsed
        ;;
    *)
        sed=sed
        ;;
esac

if ! hash ${sed} 2>/dev/null; then
    echo "You need sed \"${sed}\" to run this script ..."
    echo
    echo "On macOS: brew install gnu-sed"
    exit 43
fi

${sed} "$@"
