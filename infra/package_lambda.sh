#!/bin/bash

# Script to package Lambda function for deployment
# This script creates a zip file with the Lambda function code

set -e

LAMBDA_DIR="lambda"
ZIP_FILE="lambda_function.zip"

echo "Packaging Lambda function..."

# Remove existing zip file if it exists
if [ -f "$ZIP_FILE" ]; then
    echo "Removing existing $ZIP_FILE"
    rm "$ZIP_FILE"
fi

# Create zip file with Lambda function
if [ -d "$LAMBDA_DIR" ]; then
    echo "Packaging Lambda function from $LAMBDA_DIR"
    cd "$LAMBDA_DIR"
    zip -r "../$ZIP_FILE" .
    cd ..
    echo "Lambda function packaged successfully: $ZIP_FILE"
    
    # Show zip contents
    echo "Zip file contents:"
    unzip -l "$ZIP_FILE"
else
    echo "Lambda directory not found: $LAMBDA_DIR"
    exit 1
fi

echo "Lambda packaging complete!"
