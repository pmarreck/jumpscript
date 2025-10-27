#!/usr/bin/env jumpscript -S Crystal
# nix: {
#   buildInputs = [];
# }

puts "Hello from Crystal!"

# Process command line arguments
args = ARGV

unless args.empty?
  puts "Arguments:"
  args.each_with_index do |arg, i|
    puts "  #{i+1}: #{arg}"
  end
  
  # Try to parse numeric arguments and calculate their sum
  begin
    numeric_args = args.select { |arg| arg =~ /^-?\d+$/ }.map(&.to_i)
    
    unless numeric_args.empty?
      sum = numeric_args.sum
      puts "Sum of numeric arguments: #{sum}"
    end
  rescue ex
    puts "Error processing numeric arguments: #{ex.message}"
  end
end
