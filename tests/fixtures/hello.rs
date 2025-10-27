#!/usr/bin/env -S jumpscript Rust

use std::env;

fn main() {
    println!("Rust integration OK");
    if let Some(arg) = env::args().nth(1) {
        println!("arg={}" , arg);
    }
}
