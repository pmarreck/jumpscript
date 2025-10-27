#!/usr/bin/env jumpscript -S Nim
# nix: {
#   buildInputs = [];
# }

import os
import strutils
import sequtils
import unicode  # For isDigit

echo "Hello from Nim!"

# Process command line arguments
let args = commandLineParams()

if args.len > 0:
  echo "Arguments:"
  for i, arg in args:
    echo "  ", i+1, ": ", arg
  
  # Try to parse numeric arguments and calculate their sum
  try:
    # Helper function to check if a string is a valid integer
    proc isInteger(s: string): bool =
      if s.len == 0:
        return false
      
      var startIdx = 0
      if s[0] == '-':
        if s.len == 1:  # Just a minus sign
          return false
        startIdx = 1
      
      for i in startIdx ..< s.len:
        if not s[i].isDigit():
          return false
      
      return true
    
    let numericArgs = args.filterIt(isInteger(it))
                          .mapIt(parseInt(it))
    
    if numericArgs.len > 0:
      let sum = numericArgs.foldl(a + b)
      echo "Sum of numeric arguments: ", sum
  except:
    echo "Error processing numeric arguments"
