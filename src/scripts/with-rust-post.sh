#!/bin/bash
set -eux

sccache --stop-server

grep -F "'403" /tmp/sccache.log | head || true
