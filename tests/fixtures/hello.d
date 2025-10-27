#!/usr/bin/env -S jumpscript D

import std.stdio;

void main(string[] args) {
	writeln("D integration OK");
	if (args.length > 1) {
		writefln("arg=%s", args[1]);
	}
}
