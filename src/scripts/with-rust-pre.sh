#!/bin/bash

set -eux

sccache --version
command -v mold

export SCCACHE_IDLE_TIMEOUT="0"
export RUST_LOG="sccache=info"
export SCCACHE_ERROR_LOG=/tmp/sccache.log
export SCCACHE_LOG="info,sccache::cache=debug"
sccache --start-server

rustflags=(
  "-C linker=clang -C link-arg=-fuse-ld=/usr/local/bin/mold"
  "-C link-arg=-Wl,--compress-debug-sections=zlib"
  "-C force-frame-pointers=yes"
)

cat << EOF >> "${BASH_ENV}"
  export RUSTC_WRAPPER="sccache"
  export CARGO_INCREMENTAL="0"
  export CARGO_PROFILE_RELEASE_LTO="thin"
  export RUSTFLAGS="${rustflags[*]}"
EOF
