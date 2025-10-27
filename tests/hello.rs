#!/usr/bin/env jumpscript -S Rust
# nix: {
#   buildInputs = [];
# }

use std::env;

fn main() {
    println!("Hello from Rust!");
    
    // Get and process command line arguments
    let args: Vec<String> = env::args().skip(1).collect();
    
    if !args.is_empty() {
        println!("Arguments:");
        for (i, arg) in args.iter().enumerate() {
            println!("  {}: {}", i+1, arg);
        }
        
        // Do something a bit more complex
        let sum: i32 = args
            .iter()
            .filter_map(|s| s.parse::<i32>().ok())
            .sum();
            
        println!("Sum of numeric arguments: {}", sum);
    }
}
