#!/bin/bash

# Hop - Directory Bookmark Manager for Bash

# Configuration
BOOKMARK_FILE="$HOME/.hop_bookmarks.txt"

# Colors
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_DARK_GRAY='\033[1;30m'
COLOR_WHITE='\033[1;37m'
COLOR_BOLD_YELLOW='\033[1;33m' # For emphasis in help

# Helper functions for colored output
echo_success() { echo -e "${COLOR_GREEN}$1${COLOR_RESET}"; }
echo_error() { echo -e "${COLOR_RED}Error: $1${COLOR_RESET}"; }
echo_warning() { echo -e "${COLOR_YELLOW}Warning: $1${COLOR_RESET}"; }
echo_info() { echo -e "${COLOR_CYAN}$1${COLOR_RESET}"; }
echo_label() { echo -en "${COLOR_GREEN}$1${COLOR_RESET}"; } # No newline
echo_value() { echo -e "${COLOR_CYAN}$1${COLOR_RESET}"; }   # With newline
echo_white() { echo -en "${COLOR_WHITE}$1${COLOR_RESET}"; } # No newline
echo_bold_yellow() { echo -e "${COLOR_BOLD_YELLOW}$1${COLOR_RESET}"; }


# --- Core Bookmark Functions ---

# Load bookmarks from file into an associative array
# Usage: declare -A bookmarks; load_bookmarks bookmarks
load_bookmarks() {
    local -n _bookmarks_ref=$1 # Pass associative array by reference
    _bookmarks_ref=() # Clear the array first
    if [[ ! -f "$BOOKMARK_FILE" ]]; then
        touch "$BOOKMARK_FILE" # Create if it doesn't exist
        return 0
    fi

    local line key path category last_accessed access_count
    # Use process substitution and handle potential final line without newline
    while IFS='|' read -r key path category last_accessed access_count || [[ -n "$line" ]]; do
         # Trim potential leading/trailing whitespace just in case
         key=$(echo "$key" | sed 's/^[ \t]*//;s/[ \t]*$//')
         if [[ -n "$key" ]]; then
            _bookmarks_ref["$key"]="$path|$category|$last_accessed|$access_count"
         fi
    done < <(cat "$BOOKMARK_FILE"; echo) # Ensure last line is read if no trailing newline
}


# Save bookmarks from associative array to file
# Usage: save_bookmarks bookmarks
save_bookmarks() {
    local -n _bookmarks_ref=$1 # Pass associative array by reference
    local key data path category last_accessed access_count

    # Overwrite the file
    # Use temporary file for atomic write (safer)
    local temp_file
    temp_file=$(mktemp) || { echo_error "Failed to create temporary file for saving."; return 1; }
    # Ensure temp file is removed on exit/error
    trap 'rm -f "$temp_file"' EXIT HUP INT QUIT TERM

    # Sort keys alphabetically before saving for consistency
    local sorted_keys=()
    for key in "${!_bookmarks_ref[@]}"; do
        sorted_keys+=("$key")
    done
    # Handle potential empty array before sorting
    if [[ ${#sorted_keys[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_keys=($(sort <<<"${sorted_keys[*]}"))
        unset IFS
    fi

    for key in "${sorted_keys[@]}"; do
        data="${_bookmarks_ref[$key]}"
        echo "$key|$data" >> "$temp_file"
    done

    # Atomically replace the old file with the new one
    mv "$temp_file" "$BOOKMARK_FILE" || { echo_error "Failed to save bookmarks to $BOOKMARK_FILE"; rm -f "$temp_file"; return 1; }
    trap - EXIT HUP INT QUIT TERM # Remove trap on successful move
}

# --- Command Functions ---

add_bookmark() {
    local name="$1"
    local path_or_category="$2"
    local category_arg="$3"
    local path
    local category="general" # Default category
    local abs_path

    if [[ -z "$name" ]]; then
        echo_error "Bookmark name is required."
        echo_error "Usage: hop add <name> [<path>] [<category>]"
        echo_info "       If <path> is omitted, the current directory is used."
        return 1
    fi

    # Determine path and category based on arguments provided
    if [[ -z "$path_or_category" ]]; then
        # Case: hop add <name> (use current path)
        path=$(pwd)
    elif [[ -n "$path_or_category" ]] && [[ -z "$category_arg" ]]; then
        # Case: hop add <name> <path_or_maybe_category>
        # Heuristic: If it looks like a path (contains / or ~ or . or is an existing dir/file), treat as path. Otherwise, could be category.
        # Let's prioritize it being a path if only two args are given. User can use 'set' for current dir + category.
        # Or, a simpler rule: if 2 args, 2nd is PATH. If 3 args, 2nd is PATH, 3rd is CATEGORY.
        path="$path_or_category"
        # If path doesn't exist, maybe they meant `hop add name category`? This is ambiguous.
        # Let's stick to: 2nd arg is path.
    elif [[ -n "$path_or_category" ]] && [[ -n "$category_arg" ]]; then
         # Case: hop add <name> <path> <category>
         path="$path_or_category"
         category="$category_arg"
    fi


     # Attempt to resolve the path if specified or defaulted
    if [[ -z "$path" ]]; then
        echo_error "Could not determine path. Usage: hop add <name> [<path>] [<category>]"
        return 1
    fi

    # If path is relative, make it absolute based on current dir
    # Use realpath -m to handle non-existent paths gracefully during check, but require existence for bookmarking
    # If path doesn't exist *now*, fail.
    if [[ ! -e "$path" ]]; then
         echo_error "Path '$path' does not exist."
         return 1
    fi
     if [[ ! -d "$path" ]]; then
        echo_error "Path '$path' is not a directory."
        return 1
    fi
    abs_path=$(realpath -m "$path") # Get absolute path, resolve ., ..


    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ -v bookmarks["$name"] ]]; then
        echo_error "Bookmark '$name' already exists. Use 'hop remove $name' or 'hop rename $name ...'."
        return 1
    fi

    # Add new bookmark: path|category|last_accessed_ts|access_count
    bookmarks["$name"]="$abs_path|$category||0"
    save_bookmarks bookmarks
    echo_success "Bookmark '$name' added under category '$category' for path $abs_path"
}

set_as_bookmark() {
    local name="$1"
    local category="${2:-general}" # Default category
    local current_path

    if [[ -z "$name" ]]; then
        echo_error "Usage: hop set <name> [<category>]"
        return 1
    fi

    current_path=$(pwd)

    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ -v bookmarks["$name"] ]]; then
        echo_error "Bookmark '$name' already exists. Use 'hop remove $name' or 'hop rename $name ...'."
        return 1
    fi

    # Add new bookmark: path|category|last_accessed_ts|access_count
    bookmarks["$name"]="$current_path|$category||0"
    save_bookmarks bookmarks
    echo_success "Current location set as bookmark '$name' under category '$category' at $current_path"
}

rename_bookmark() {
    # This function remains largely the same as before
    local old_name="$1"
    local new_name="$2"
    local maybe_c="$3"
    local new_category="$4"
    local target_name data path category last_accessed access_count print_only=0

    if [[ -z "$old_name" ]]; then
        echo_error "Specify the old bookmark name."
        echo_error "Usage: hop rename <oldname> <newname>"
        echo_error "       hop rename <oldname> -c <newcategory>"
        echo_error "       hop rename <oldname> <newname> -c <newcategory>"
        return 1
    fi

    # Improved parsing for -c flag
    if [[ "$new_name" == "-c" ]] && [[ -n "$maybe_c" ]]; then
        # Case: hop rename oldname -c category
        new_category="$maybe_c"
        new_name="" # No name change
    elif [[ "$maybe_c" == "-c" ]] && [[ -n "$new_category" ]]; then
        # Case: hop rename oldname newname -c category
        # new_name is already set to $2
        # new_category is already set to $4
        : # Do nothing, variables are correct
    elif [[ -n "$new_name" ]] && [[ -z "$maybe_c" ]]; then
        # Case: hop rename oldname newname (no category change)
        new_category=""
    else
        # Invalid combination or missing arguments
        echo_error "Invalid arguments for rename."
        echo_error "Usage: hop rename <oldname> <newname>"
        echo_error "       hop rename <oldname> -c <newcategory>"
        echo_error "       hop rename <oldname> <newname> -c <newcategory>"
        return 1
    fi

    if [[ -z "$new_name" ]] && [[ -z "$new_category" ]]; then
        echo_error "Specify either a new name or a new category using '-c <category>'."
        return 1
    fi

    declare -A bookmarks
    load_bookmarks bookmarks

    if ! [[ -v bookmarks["$old_name"] ]]; then
        echo_error "Bookmark '$old_name' not found."
        return 1
    fi

    # Handle renaming
    if [[ -n "$new_name" ]]; then
        if [[ "$new_name" != "$old_name" ]] && [[ -v bookmarks["$new_name"] ]]; then
            echo_error "Bookmark '$new_name' already exists. Choose a different name."
            return 1
        fi
        # Copy data to new key and remove old one *only if name actually changes*
        if [[ "$new_name" != "$old_name" ]]; then
            bookmarks["$new_name"]="${bookmarks[$old_name]}"
            unset bookmarks["$old_name"]
            echo_success "Bookmark '$old_name' renamed to '$new_name'."
        fi
        target_name="$new_name"
    else
        target_name="$old_name" # Only changing category
    fi

    # Handle category change
    if [[ -n "$new_category" ]]; then
        # Ensure the target bookmark exists (could have been renamed)
        if ! [[ -v bookmarks["$target_name"] ]]; then
             echo_error "Internal error: Target bookmark '$target_name' not found after potential rename."
             return 1
        fi
        data="${bookmarks[$target_name]}"
        # Read existing data, splitting carefully
        IFS='|' read -r path _category_old last_accessed access_count <<< "$data"
        bookmarks["$target_name"]="$path|$new_category|$last_accessed|$access_count" # Rebuild with new category
        echo_success "Category for bookmark '$target_name' changed to '$new_category'."
    fi

    save_bookmarks bookmarks
}


# Jumps to a bookmark. Default: starts a new shell. With -p: prints path.
go_to_bookmark() {
    local name="$1"
    local print_only_flag="$2"
    local print_only=0

    if [[ -z "$name" ]]; then
        echo_error "Usage: hop to <name> [-p|--print]"
        echo_info "       Default behavior starts a new shell in the directory."
        echo_info "       Use '-p' or '--print' to only print the path for use with cd \"\$(...)\"."
        return 1
    fi

    # Check for the print-only flag
    if [[ "$print_only_flag" == "-p" ]] || [[ "$print_only_flag" == "--print" ]]; then
        print_only=1
    fi

    declare -A bookmarks
    load_bookmarks bookmarks

    if ! [[ -v bookmarks["$name"] ]]; then
        echo_error "Bookmark '$name' not found."
        return 1
    fi

    local data path category last_accessed access_count current_time
    data="${bookmarks[$name]}"
    IFS='|' read -r path category last_accessed access_count <<< "$data"

    # Check if path still exists and is a directory
    if [[ ! -d "$path" ]]; then
        echo_error "The bookmarked path '$path' for '$name' is not a valid directory. Please remove or update the bookmark."
        return 1
    fi

    # Update stats
    current_time=$(date +%s)
    ((access_count++))
    bookmarks["$name"]="$path|$category|$current_time|$access_count"
    save_bookmarks bookmarks # Save stats regardless of mode

    if [[ $print_only -eq 1 ]]; then
        # Print the path only
        echo "$path"
        return 0
    else
        # Change directory and execute a new shell
        echo_info "Changing directory to '$path' and starting a new shell..."
        echo_info "Type 'exit' or press Ctrl+D to return to the previous shell."
        cd "$path" || { echo_error "Failed to change directory to '$path'."; return 1; }
        # Replace the current script process with a new shell
        exec "$SHELL"
        # The 'exec' command replaces the current process, so the script ends here.
        # If 'exec' fails for some reason, we'll hit this error.
        echo_error "Failed to execute shell '$SHELL'. You are still in the original shell."
        return 1
    fi
}

list_bookmarks() {
    # This function remains largely the same as before
    local filter_type="" # "word" or "category"
    local filter_value=""

    if [[ "$1" == "-c" ]] && [[ -n "$2" ]]; then
        filter_type="category"
        filter_value="$2"
    elif [[ -n "$1" ]]; then
        filter_type="word"
        filter_value="$1"
    fi

    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ ${#bookmarks[@]} -eq 0 ]]; then
        echo_warning "No bookmarks found."
        return 0
    fi

    local key data path category output_count=0
    local sorted_keys=()
    for key in "${!bookmarks[@]}"; do
        sorted_keys+=("$key")
    done

    if [[ ${#sorted_keys[@]} -eq 0 ]]; then
       # This case should ideally not be reached if the earlier check works, but good practice
       echo_warning "No bookmarks loaded."
       return 0
    fi

    IFS=$'\n' sorted_keys=($(sort <<<"${sorted_keys[*]}"))
    unset IFS


    for key in "${sorted_keys[@]}"; do
        data="${bookmarks[$key]}"
        IFS='|' read -r path category _ _ <<< "$data"

        local match=0
        if [[ -z "$filter_type" ]]; then
            match=1 # No filter, list all
        elif [[ "$filter_type" == "word" ]] && [[ "$key" == *"$filter_value"* ]]; then
            match=1 # Match keyword in name
        elif [[ "$filter_type" == "category" ]] && [[ "$category" == "$filter_value" ]]; then
            match=1 # Match category
        fi

        if [[ $match -eq 1 ]]; then
            echo_label "$key " # Print key in green (no newline)
            echo_value "$path" # Print path in cyan (with newline)
            ((output_count++))
        fi
    done

     if [[ $output_count -eq 0 ]] && [[ -n "$filter_type" ]]; then
        echo_warning "No bookmarks found matching your criteria."
    fi
}

show_stats() {
    # This function remains largely the same as before
    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ ${#bookmarks[@]} -eq 0 ]]; then
        echo_warning "No bookmarks found."
        return 0
    fi

    # Header
    printf "%-25s %-15s %-7s %-20s %s\n" "Bookmark" "Category" "Count" "Last Access" "Path"
    printf "%-25s %-15s %-7s %-20s %s\n" "-------------------------" "---------------" "-------" "--------------------" "----"

    local key data path category last_accessed_ts access_count last_accessed_str
    local sorted_keys=()
    for key in "${!bookmarks[@]}"; do
        sorted_keys+=("$key")
    done
     if [[ ${#sorted_keys[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_keys=($(sort <<<"${sorted_keys[*]}"))
        unset IFS
    fi

    for key in "${sorted_keys[@]}"; do
        data="${bookmarks[$key]}"
        IFS='|' read -r path category last_accessed_ts access_count <<< "$data"

        if [[ -n "$last_accessed_ts" ]] && [[ "$last_accessed_ts" =~ ^[0-9]+$ ]]; then
            # Attempt to format date - might vary slightly based on `date` version
            last_accessed_str=$(date -d "@$last_accessed_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid Date")
        else
            last_accessed_str="Never"
        fi
        access_count=${access_count:-0} # Default to 0 if empty

        printf "%-25s %-15s %-7s %-20s %s\n" "$key" "$category" "$access_count" "$last_accessed_str" "$path"
    done
}

show_recent() {
    # This function remains largely the same as before
    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ ${#bookmarks[@]} -eq 0 ]]; then
        echo_warning "No bookmarks found."
        return 0
    fi

    echo_info "Recently Accessed Bookmarks (Top 10):"
    local key data last_accessed_ts last_accessed_str count=0
    # Use process substitution for sorting and reading
    # Ensure only lines with valid timestamps are processed
    # Sort numerically descending by timestamp (field 1), take top 10
    while IFS='|' read -r _ key last_accessed_str; do
         echo_label "$key -> "
         echo_value "Last Accessed: $last_accessed_str"
         ((count++))
    done < <(
        for key in "${!bookmarks[@]}"; do
            data="${bookmarks[$key]}"
            IFS='|' read -r _ _ last_accessed_ts _ <<< "$data"
            if [[ -n "$last_accessed_ts" ]] && [[ "$last_accessed_ts" =~ ^[0-9]+$ ]]; then
                last_accessed_str=$(date -d "@$last_accessed_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid Date")
                # Use printf for safer output, ensure timestamp is first for sort
                printf "%s|%s|%s\n" "$last_accessed_ts" "$key" "$last_accessed_str"
             fi
        done | sort -t'|' -k1,1nr | head -n 10
    )

    if [[ $count -eq 0 ]]; then
        echo_warning "No bookmarks with access times found."
    fi
}


show_frequent() {
    # This function remains largely the same as before
    declare -A bookmarks
    load_bookmarks bookmarks

    if [[ ${#bookmarks[@]} -eq 0 ]]; then
        echo_warning "No bookmarks found."
        return 0
    fi

    echo_info "Frequently Accessed Bookmarks (Top 10):"
     local key data access_count count=0
     # Use process substitution for sorting and reading
     # Sort numerically descending by access count (field 1), take top 10
    while IFS='|' read -r freq_count key; do
        echo_label "$key -> "
        echo_value "Access Count: $freq_count"
        ((count++))
    done < <(
        for key in "${!bookmarks[@]}"; do
            data="${bookmarks[$key]}"
            IFS='|' read -r _ _ _ access_count <<< "$data"
            access_count=${access_count:-0} # Default to 0 if missing
            # Use printf for safer output, ensure count is first for sort
            printf "%s|%s\n" "$access_count" "$key"
        done | sort -t'|' -k1,1nr | head -n 10
    )

    if [[ $count -eq 0 ]]; then
        # This case is unlikely if bookmarks exist, but good practice
        echo_warning "No bookmark access counts found."
    fi
}

remove_bookmark() {
    # This function remains largely the same as before
    local name="$1"
    if [[ -z "$name" ]]; then
        echo_error "Usage: hop remove <name>"
        return 1
    fi

    declare -A bookmarks
    load_bookmarks bookmarks

    if ! [[ -v bookmarks["$name"] ]]; then
        echo_error "Bookmark '$name' not found."
        return 1
    fi

    unset bookmarks["$name"]
    save_bookmarks bookmarks
    echo_warning "Bookmark '$name' removed." # Use warning color for removal
}


clear_bookmarks() {
    # This function remains largely the same as before
    echo_warning "This action will delete ALL bookmarks permanently from $BOOKMARK_FILE!"
    read -p "Are you sure you want to proceed? Type 'yes' to confirm: " confirmation

    if [[ "$confirmation" == "yes" ]]; then
        rm -f "$BOOKMARK_FILE" && touch "$BOOKMARK_FILE" # Remove and recreate empty file
        echo_error "All bookmarks cleared." # Use error color for destructive action
    else
        echo_success "Operation canceled. No bookmarks were cleared."
    fi
}

show_help() {
    echo_success "Hop Bookmark Management Help (Bash Version)"
    echo ""
    echo_info "Primary Goal: Quickly navigate between frequently used directories."
    echo ""
    echo_info "Navigation:"
    # Explain 'hop to' default behavior (new shell)
    echo_white "  hop to <name>"; echo -e "                   - ${COLOR_BOLD_YELLOW}Starts a new shell session${COLOR_RESET} in the bookmarked directory."
    echo_white "                                     "; echo -e "    ${COLOR_YELLOW}Type 'exit' or Ctrl+D to return${COLOR_RESET} to your previous shell."
    # Explain 'hop to -p' alternative (print path)
    echo_white "  hop to <name> -p"; echo -e " (or --print)  - Prints the directory path instead of starting a new shell."
    echo_white "                                     "; echo -e "    Usage: ${COLOR_CYAN}cd \"\$(hop to <name> -p)\"${COLOR_RESET}"
    echo ""
    echo_info "Bookmark Management:"
    # Explain 'hop add' with optional path/category and default current directory
    echo_white "  hop add <name> [<path>] [<category>]"; echo -e " - Adds a bookmark."
    echo_white "                                     "; echo -e "   - If <path> is omitted, the ${COLOR_YELLOW}current directory is used${COLOR_RESET}."
    echo_white "                                     "; echo -e "   - Default category is 'general'."
    # Explain 'hop set'
    echo_white "  hop set <name> [<category>]"; echo -e "        - Sets the current directory as a bookmark."
    # Explain 'hop rename' variations
    echo_white "  hop rename <old> <new>"; echo -e "           - Renames bookmark <old> to <new>."
    echo_white "  hop rename <old> -c <category>"; echo -e "    - Changes the category of bookmark <old>."
    echo_white "  hop rename <old> <new> -c <cat>"; echo -e "   - Renames and changes the category simultaneously."
    # Explain 'hop remove'
    echo_white "  hop remove <name>"; echo -e "         - Removes the specified bookmark."
    # Explain 'hop clear'
    echo_white "  hop clear"; echo -e "                 - ${COLOR_RED}Removes ALL bookmarks${COLOR_RESET} (requires confirmation)."
    echo ""
    echo_info "Listing and Information:"
    # Explain 'hop list' variations
    echo_white "  hop list [<word>]"; echo -e "               - Lists all bookmarks, or those with names containing <word>." # Corrected echo flags here
    echo_white "  hop list -c <category>"; echo -e "        - Lists bookmarks within a specific <category>." # Corrected echo flags here
    # Explain 'hop stats'
    echo_white "  hop stats"; echo -e "                  - Displays detailed statistics (path, category, access count, last access)." # Corrected echo flags here
    # Explain 'hop recent'
    echo_white "  hop recent"; echo -e "               - Shows the 10 most recently accessed bookmarks." # Corrected echo flags here
    # Explain 'hop frequent'
    echo_white "  hop frequent"; echo -e "           - Shows the 10 most frequently accessed bookmarks." # Corrected echo flags here
    echo ""
    echo_info "Utility:"
    # Explain 'hop help'
    echo_white "  hop help"; echo -e "                  - Displays this help information." # Corrected echo flags here
    echo ""

    echo_info "Setup:"
     echo -e "  ${COLOR_DARK_GRAY}1. Save this script to a file (e.g., ~/bin/hop or ~/.local/bin/hop)."
     echo -e "  ${COLOR_DARK_GRAY}2. Make it executable: chmod +x ~/bin/hop"
     echo -e "  ${COLOR_DARK_GRAY}3. Ensure the directory is in your PATH. Add this to your ~/.bashrc or ~/.zshrc if needed:"
     echo -e "  ${COLOR_DARK_GRAY}     export PATH=\"\$HOME/bin:\$PATH\ (use ~/.local/bin if you prefer)"
     echo -e "  ${COLOR_DARK_GRAY}4. Reload your shell configuration:"
     echo -e "  ${COLOR_DARK_GRAY}    source ~/.bashrc$  (or source ~/.zshrc)"
     echo -e "  ${COLOR_DARK_GRAY}Alternatively to steps 3 & 4, create an alias in ~/.bashrc or ~/.zshrc:"
     echo -e "  ${COLOR_DARK_GRAY}     alias hop='/full/path/to/your/hop/script'"
     echo -e "  ${COLOR_DARK_GRAY}   Then run source ~/.bashrc (or .zshrc)."
    echo ""
    echo_info "Notes:"
    echo -e "  ${COLOR_DARK_GRAY}- Use quotes around names, paths, or categories containing spaces."
    echo -e "  ${COLOR_DARK_GRAY}- The bookmark file is stored at: ${BOOKMARK_FILE}"
    echo -e "  ${COLOR_DARK_GRAY}- The 'hop to <name>' command starts a nested shell session}${COLOR_DARK_GRAY}. Your original shell is paused until you 'exit' the new one."
}

# --- Main Execution Logic ---

# Check if any arguments were passed
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

# Command dispatcher
COMMAND="$1"
shift # Remove command name from argument list for subsequent functions

case "$COMMAND" in
    help|-h|--help)
        show_help
        ;;
    add)
        add_bookmark "$@"
        ;;
    set)
        set_as_bookmark "$@"
        ;;
    to)
        go_to_bookmark "$@" # Handles new shell or printing path
        ;;
    list)
        list_bookmarks "$@"
        ;;
    stats)
        show_stats
        ;;
    recent)
        show_recent
        ;;
    frequent)
        show_frequent
        ;;
    remove)
        remove_bookmark "$@"
        ;;
    rename)
        rename_bookmark "$@"
        ;;
    clear)
        clear_bookmarks
        ;;
    init) # Keep this case for users migrating
        echo_info "The 'init' command is not needed in the Bash version."
        echo_info "Please follow the setup instructions in 'hop help' to make the script callable."
        ;;
    *)
        echo_error "Unknown command: '$COMMAND'. Use 'hop help' for instructions."
        exit 1
        ;;
esac

# Exit with the status of the last command executed
# Note: If `hop to` was successful without -p, `exec` replaces this process, so this exit code isn't reached.
exit $?
