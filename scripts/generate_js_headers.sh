base_dir="$(pwd)"

for ((i = 0; i < "${#nativescript_js_inputs[@]}"; i++))
do
    input_file_path=${nativescript_js_inputs[$i]}
    output_file_path=${nativescript_js_outputs[$i]}

    echo "Generating $output_file_path from $input_file_path..."
    cd "$(dirname "$input_file_path")"
    xxd -i "$(basename "$input_file_path")" > "$output_file_path"
    cd "$base_dir"
done