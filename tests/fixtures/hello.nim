#!/usr/bin/env -S jumpscript Nim

import os

echo "Nim integration OK"
let args = commandLineParams()
if args.len > 0:
  echo "arg=" & args[0]
