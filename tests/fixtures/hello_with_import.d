#!/usr/bin/env -S jumpscript D

import std.stdio;
import hello_helper;

int main(string[] args) {
	writeln(hello_helper.message());
	return 0;
}
