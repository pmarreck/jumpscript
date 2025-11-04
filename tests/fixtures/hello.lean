#!/usr/bin/env -S jumpscript Lean

import Lean

open IO

def main (args : List String) : IO Unit := do
  println! "Lean integration OK"
  match args with
  | first :: _ => println! "arg={first}"
  | _ => pure ()
