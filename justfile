default:
    @just --list

setup:
    meson setup build

build: setup
    meson compile -C build

test: build
    meson test -C build --print-errorlogs

check-shell:
    shellcheck --shell=bash developer/*.sh
    shfmt --diff --language-dialect bash developer/*.sh

# Build, sign, and verify the arm64 production application bundle.
release: check-shell
    /bin/bash developer/release.sh

verify: build check-shell
    meson compile -C build verify

verify-asan:
    meson setup build-asan -Dbuildtype=debug -Db_lto=false -Db_lundef=false -Db_sanitize=address,undefined,bounds,float-divide-by-zero,implicit-conversion,integer,nullability -Ddeveloper_checks=enabled
    meson compile -C build-asan
    meson compile -C build-asan verify

verify-tsan:
    meson setup build-tsan -Dbuildtype=debug -Db_lto=false -Db_lundef=false -Db_sanitize=thread -Ddeveloper_checks=enabled
    meson compile -C build-tsan
    meson compile -C build-tsan verify

verify-llvm:
    if test -d build-llvm/meson-private; then env CC=/opt/homebrew/opt/llvm/bin/clang OBJC=/opt/homebrew/opt/llvm/bin/clang AR=/opt/homebrew/opt/llvm/bin/llvm-ar RANLIB=/opt/homebrew/opt/llvm/bin/llvm-ranlib meson setup --wipe build-llvm -Ddeveloper_checks=enabled; else env CC=/opt/homebrew/opt/llvm/bin/clang OBJC=/opt/homebrew/opt/llvm/bin/clang AR=/opt/homebrew/opt/llvm/bin/llvm-ar RANLIB=/opt/homebrew/opt/llvm/bin/llvm-ranlib meson setup build-llvm -Ddeveloper_checks=enabled; fi
    env CC=/opt/homebrew/opt/llvm/bin/clang OBJC=/opt/homebrew/opt/llvm/bin/clang AR=/opt/homebrew/opt/llvm/bin/llvm-ar RANLIB=/opt/homebrew/opt/llvm/bin/llvm-ranlib meson compile -C build-llvm
    env CC=/opt/homebrew/opt/llvm/bin/clang OBJC=/opt/homebrew/opt/llvm/bin/clang AR=/opt/homebrew/opt/llvm/bin/llvm-ar RANLIB=/opt/homebrew/opt/llvm/bin/llvm-ranlib meson compile -C build-llvm verify

verify-matrix: verify verify-asan verify-tsan verify-llvm

format: setup
    meson compile -C build format
    shfmt --write --language-dialect bash developer/*.sh

clean: setup
    meson compile -C build clean
