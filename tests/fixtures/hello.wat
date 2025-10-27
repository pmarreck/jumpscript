#!/usr/bin/env -S jumpscript Wat
(module
  (type $t0 (func (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (type $t0)))
  (memory 1)
  (export "memory" (memory 0))
  (data (i32.const 0) "WAT hello\n")
  (func $_start
    (i32.store (i32.const 16) (i32.const 0))
    (i32.store (i32.const 20) (i32.const 10))
    (call $fd_write
      (i32.const 1)
      (i32.const 16)
      (i32.const 1)
      (i32.const 24))
    drop)
  (export "_start" (func $_start)))
