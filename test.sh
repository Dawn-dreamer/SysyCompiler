#!/bin/bash


# Check command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [-a|-r] [filename]"
    echo "  -a: compile all files in tests directory"
    echo "  -r filename: compile and/or run a specific file"
    exit 1
fi
if [ "$1" = "-c" ]; then
    # Remove all files in test directory except .sy files
    find tests ! -name '*.sy' -type f -delete
    exit 0
fi

# Compile all files in tests directory
if [ "$1" = "-a" ]; then
    for file in tests/*.sy
    do
        # Extract file name without extension
        filename=$(basename -- "$file")
        filename="${filename%.*}"

        # Compile file and save output to test directory
        ./sysy_compiler < "$file" > "tests/$filename.s"
    done

# Compile and/or run a specific file
else
    # Extract file name without extension
    filename=$(basename -- "$2")
    filename="${filename%.*}"

    # Compile file and save output to test directory
    ./sysy_compiler < "tests/$2" > "tests/$filename.s"

    # Run compiled file if -r option is specified
    if [ "$1" = "-r" ]; then
        gcc -o "tests/$filename" "tests/$filename.s"
        "./tests/$filename"
    fi
fi
