#!/usr/bin/env jumpscript -S C
# nix: {
#   buildInputs = [ pkgs.zlib ];
# }

#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(int argc, char *argv[]) {
    printf("Hello from C!\n");
    
    // Print any arguments passed to the script
    if (argc > 1) {
        printf("Arguments:\n");
        for (int i = 1; i < argc; i++) {
            printf("  %d: %s\n", i, argv[i]);
        }
    }
    
    // Demonstrate using a library (zlib)
    printf("Using zlib version: %s\n", zlibVersion());
    
    return 0;
}
