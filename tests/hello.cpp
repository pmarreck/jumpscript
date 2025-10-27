#!/usr/bin/env jumpscript -S C++
# nix: {
#   buildInputs = [ pkgs.boost ];
# }

#include <iostream>
#include <vector>
#include <string>
#include <boost/algorithm/string.hpp>

int main(int argc, char *argv[]) {
    std::cout << "Hello from C++!\n";
    
    // Process arguments
    std::vector<std::string> args(argv + 1, argv + argc);
    
    if (!args.empty()) {
        std::cout << "Arguments:\n";
        for (size_t i = 0; i < args.size(); ++i) {
            std::cout << "  " << i+1 << ": " << args[i] << "\n";
        }
        
        // Demonstrate using boost
        std::string joined = boost::algorithm::join(args, ", ");
        std::cout << "All args joined: " << joined << "\n";
    }
    
    return 0;
}
