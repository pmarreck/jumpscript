#!/usr/bin/env -S jumpscript Idris

module Main

import System

main : IO ()
main = do
  putStrLn "Idris integration OK"
  args <- getArgs
  case args of
    _ :: first :: _ => putStrLn $ "arg=" ++ first
    _ => pure ()
