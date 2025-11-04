#!/usr/bin/env -S jumpscript C
#include <stdio.h>

int main(int argc, char *argv[]) {
	puts("C integration OK");
	if (argc > 1) {
		printf("arg=%s\n", argv[1]);
	}
	return 0;
}
