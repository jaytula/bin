#!/bin/bash

# A script to recursively find all .php files, and concatenate them
# into a single text stream, formatted for an AI prompt.
#
# Each file's content is prefixed with a comment indicating its
# relative path and wrapped in Markdown PHP code fences.

# The starting directory is the current directory.
START_DIR="."

# Use 'find' to locate all files ending in .php.
# The output is piped to a 'while' loop to process each file.
# Using 'read -r' is important to handle special characters in filenames.
find "$START_DIR" -type f -name "*.php" | while read -r filepath; do
  # Print the header comment with the relative file path.
  echo "// File: ${filepath}"

  # Print the opening Markdown code fence for PHP.
  echo "\`\`\`php"

  # Print the content of the file.
  cat "${filepath}"

  # Print the closing Markdown code fence.
  echo "\`\`\`"

  # Add a blank line for better separation between files.
  echo ""
done