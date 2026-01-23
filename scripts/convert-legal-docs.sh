#!/bin/bash

# Convert legal .txt documents to HTML for Firebase Hosting

echo "Converting legal documents to HTML..."

# Function to convert text to HTML
convert_to_html() {
    local input_file=$1
    local output_file=$2
    local title=$3

    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TITLE_PLACEHOLDER - Heirloom</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        pre {
            white-space: pre-wrap;
            word-wrap: break-word;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        }
        a {
            color: #3498db;
        }
    </style>
</head>
<body>
    <pre>
EOF

    # Replace title placeholder
    sed -i '' "s/TITLE_PLACEHOLDER/$title/g" "$output_file"

    # Append the content
    cat "$input_file" >> "$output_file"

    # Close HTML tags
    cat >> "$output_file" << 'EOF'
    </pre>
</body>
</html>
EOF

    echo "✓ Created $output_file"
}

# Convert each document
convert_to_html "PRIVACY_POLICY.txt" "public/privacy.html" "Privacy Policy"
convert_to_html "TERMS_OF_SERVICE.txt" "public/terms.html" "Terms of Service"
convert_to_html "EULA.txt" "public/eula.html" "End User License Agreement"

# Copy support.html
cp support.html public/support.html
echo "✓ Copied support.html"

# Create index.html
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Heirloom - Legal Documents</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #2c3e50;
        }
        ul {
            list-style: none;
            padding: 0;
        }
        li {
            margin: 15px 0;
        }
        a {
            color: #3498db;
            text-decoration: none;
            font-size: 18px;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h1>Heirloom</h1>
    <p>Legal Documents and Support</p>
    <ul>
        <li><a href="/privacy.html">Privacy Policy</a></li>
        <li><a href="/terms.html">Terms of Service</a></li>
        <li><a href="/eula.html">End User License Agreement</a></li>
        <li><a href="/support.html">Support</a></li>
    </ul>
</body>
</html>
EOF
echo "✓ Created index.html"

echo "✓ All legal documents converted to HTML"
echo ""
echo "Files created in public/:"
ls -lh public/
