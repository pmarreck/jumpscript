#!/usr/bin/env jumpscript -S D
# nix: {
#   buildInputs = [];
# }

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.uni; // For isNumber
import std.string; // For string operations

void main(string[] args) {
    writeln("Hello from D!");
    
    // Process arguments (skip the program name)
    args = args[1..$];
    
    if (args.length > 0) {
        writeln("Arguments:");
        foreach (i, arg; args) {
            writefln("  %d: %s", i+1, arg);
        }
        
        // Try to parse numeric arguments and calculate their sum
        try {
            // Check if a string can be converted to an integer
            bool canBeInt(string s) {
                try {
                    to!int(s);
                    return true;
                } catch (Exception) {
                    return false;
                }
            }
            
            auto numericArgs = args
                .filter!(a => canBeInt(a))
                .map!(a => to!int(a))
                .array;
                
            if (numericArgs.length > 0) {
                int sum = numericArgs.sum();
                writefln("Sum of numeric arguments: %d", sum);
            }
        } catch (Exception e) {
            writeln("Error processing numeric arguments: ", e.msg);
        }
    }
}
