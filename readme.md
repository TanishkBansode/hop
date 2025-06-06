# Hop - Bookmark Manager for Your Terminal

A simple terminal-based tool designed to help you quickly store, navigate, and manage your favorite file paths right from the terminal. 

---

## Features

- **Add Bookmarks**: Store frequently used file paths with custom names.
- **Navigate Quickly**: Jump to any saved bookmark with a single command.
- **Recent Bookmarks**: View the most recently accessed bookmarks.
- **Categorization**: Organize bookmarks into custom categories (e.g., work, education, personal).

---

## Prerequisites

- **PowerShell** (Windows, macOS, or Linux)
- **A terminal**: PowerShell, Git Bash, Hyper, or any other terminal you prefer.

---

## Installation

### 1. Clone the Repository

Start by cloning the repository to your local machine.

```bash
git clone https://github.com/TanmayBansode/hop.git
```

### 2. Add the Script to Your Path


To use the `hop.ps1` script from anywhere in your terminal, you can either move it to a directory already in your system’s `PATH` or create an alias for it in PowerShell.

### **Option 1: Move `hop.ps1` to a Directory in Your `PATH`**

#### On **Windows**:
1. Move the `hop.ps1` file to a directory like `C:\Scripts` (or any directory you prefer).
2. Add that directory to your `PATH` environment variable:
   - Press `Win + X` and select "System".
   - Click "Advanced system settings" and then "Environment Variables".
   - Under "System variables", select `Path` and click "Edit".
   - Add the directory (`C:\Scripts`) to the list of paths.

#### On **macOS** or **Linux**:
1. Move the `hop.ps1` file to `/usr/local/bin/` or any directory listed in your `$PATH`:
   ```bash
   sudo mv hop.ps1 /usr/local/bin/hop
   ```

### **Option 2: Create an Alias in PowerShell**

Alternatively, you can create an alias in PowerShell to make the `hop` command accessible from anywhere.

1. Open your PowerShell profile file. If you don't have one, create it by running:
   ```bash
   notepad $PROFILE
   ```
   This will open your PowerShell profile in Notepad.

2. Add the following line to the profile file to create an alias for `hop.ps1`:
   ```bash
   Set-Alias hop "C:\path\to\hop.ps1"
   ```

   Replace `C:\path\to\hop.ps1` with the actual path to your `hop.ps1` file.

3. Save the profile file and restart your PowerShell terminal.

Now, you can use `hop` directly from anywhere in your terminal!



### 3. Set Execution Policy (if needed)

Ensure that your PowerShell allows running scripts. You might need to set the execution policy to allow running scripts:

```bash
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Usage

### 1. Add a Bookmark

To add a bookmark with a name and a path, use the following command:

```bash
hop add <name> <path> [<category>]
```

Example:

```bash
hop add project1 "C:\Users\YourName\Documents\Projects\Project1" "work"
```

- `name`: The name of your bookmark.
- `path`: The full file or folder path to bookmark.
- `category`: Optional. Categorize your bookmarks (e.g., `work`, `personal`).

### 2. Navigate to a Bookmark

To quickly jump to a bookmarked location, use:

```bash
hop to <name>
```

Example:

```bash
hop to project1
```

This will navigate you to the path you bookmarked.

### 2. Current Directory as a Bookmark

To set current directory as a bookmark, use:

```bash
hop set <name>
```

Example:

```bash
hop set important
```

This will set current directory bookmarked with name "important"

### 4. List Bookmarks

To list all saved bookmarks:

```bash
hop list
```

To search for a specific bookmark by name or part of the name:

```bash
hop list <search-term>
```

Example:

```bash
hop list project
```

To filter bookmarks by category:

```bash
hop list -t <category>
```

Example:

```bash
hop list -t work
```

### 5. Recent Bookmarks

To list the most recently accessed bookmarks, use:

```bash
hop recent
```

### 6. Frequent Bookmarks

To list the most frequently accessed bookmarks, use:

```bash
hop frequent
```

### 7. View Bookmark Statistics

To view detailed stats of all bookmarks (including last accessed time and access count):

```bash
hop stats
```

### 8. Remove a Bookmark

To remove a bookmark:

```bash
hop remove <name>
```

Example:

```bash
hop remove project1
```

### 9. Clear All Bookmarks

To delete all bookmarks, with a warning and confirmation prompt:

```bash
hop clear
```

You will be asked to type `yes` to confirm the action.

### 10. Show Help

For a list of all commands and usage examples:

```bash
hop help
```


---

## Contribution

We welcome contributions! If you'd like to contribute to this project, feel free to fork the repository and submit a pull request.

---
