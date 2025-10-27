#!/usr/bin/env jumpscript -S Idris
# nix: {
#   buildInputs = [];
# }

module Main

import System
import Data.String
import Data.List

parseInteger : String -> Maybe Integer
parseInteger str = 
  if all (\c => isDigit c || c == '-') (unpack str)
  then Just (cast str)
  else Nothing

main : IO ()
main = do
  putStrLn "Hello from Idris!"
  
  args <- getArgs
  let args' = drop 1 args  -- Drop program name
  
  case args' of
    [] => pure ()
    _ => do
      putStrLn "Arguments:"
      -- Use indices function to create a list of indices
      let indices = [1..length args']
      for_ (zip indices args') $ \(i, arg) => 
        putStrLn $ "  " ++ show i ++ ": " ++ arg
      
      -- Try to parse numeric arguments and calculate their sum
      let numericArgs = mapMaybe parseInteger args'
      case numericArgs of
        [] => pure ()
        _ => putStrLn $ "Sum of numeric arguments: " ++ show (sum numericArgs)
