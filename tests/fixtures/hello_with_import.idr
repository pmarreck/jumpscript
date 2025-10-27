#!/usr/bin/env -S jumpscript Idris

module Main

import HelloHelper
import System

main : IO ()
main = do
	putStrLn HelloHelper.message
	args <- getArgs
	case args of
		_ :: first :: _ => putStrLn $ "arg=" ++ first
		_ => pure ()
