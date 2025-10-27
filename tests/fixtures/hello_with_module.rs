#!/usr/bin/env -S jumpscript Rust

mod hello_helper;

fn main() {
	println!("{}", hello_helper::message());
}
