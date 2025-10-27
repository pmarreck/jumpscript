#!/usr/bin/env -S jumpscript C++
#include <iostream>
#include <vector>
#include <string>

int main(int argc, char *argv[]) {
    std::cout << "C++ integration OK" << std::endl;

    std::vector<std::string> args(argv + 1, argv + argc);
    if (!args.empty()) {
        std::cout << "arg=" << args.front() << std::endl;
    }
    return 0;
}
