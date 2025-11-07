#!/usr/bin/env bash
# Functions for package creation and management

# Main package command dispatcher
_mt_package() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    new)
      _mt_package_new "$@"
      ;;
    *)
      echo "Usage: mt package <command>"
      echo ""
      echo "Commands:"
      echo "  new NAME [PATH]      Create a new package from template"
      echo ""
      return 1
      ;;
  esac
}

# Create a new package from template
_mt_package_new() {
  local package_name=""
  local target_path=""
  local module_name=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        cat << EOF
Create a new metool package from template

Usage: mt package new NAME [PATH]

Arguments:
  NAME              Package name (lowercase-with-hyphens)
  PATH              Target directory (default: current directory)

Options:
  -h, --help        Show this help message

The command will create a new package directory with:
  - README.md with TODO placeholders
  - SKILL.md.example for Claude Code integration
  - bin/ with example executable
  - shell/ with functions and aliases
  - config/ with example configuration
  - lib/ with helper functions

Examples:
  mt package new my-tools              # Create in current directory
  mt package new my-tools ~/packages   # Create in ~/packages
  mt package new dev-helpers .         # Create in current directory

After creation:
  1. Edit README.md and fill in TODO items
  2. Optionally rename SKILL.md.example to SKILL.md and customize
  3. Add your executables to bin/
  4. Add shell functions to shell/functions
  5. Install with: mt install <module>/my-tools

EOF
        return 0
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$package_name" ]]; then
          package_name="$1"
        elif [[ -z "$target_path" ]]; then
          target_path="$1"
        else
          _mt_error "Too many arguments"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate package name
  if [[ -z "$package_name" ]]; then
    _mt_error "Package name is required"
    echo "Usage: mt package new NAME [PATH]"
    return 1
  fi

  # Validate package name format (lowercase with hyphens)
  if ! [[ "$package_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    _mt_error "Invalid package name: $package_name"
    echo "Package name must be lowercase with hyphens (e.g., my-package)"
    return 1
  fi

  # Default to current directory if no path provided
  if [[ -z "$target_path" ]]; then
    target_path="."
  fi

  # Resolve target path
  target_path="$(realpath "$target_path")"
  local package_dir="${target_path}/${package_name}"

  # Check if package directory already exists
  if [[ -d "$package_dir" ]]; then
    _mt_error "Package directory already exists: $package_dir"
    return 1
  fi

  # Template directory
  local template_dir="${MT_ROOT}/templates/package"

  if [[ ! -d "$template_dir" ]]; then
    _mt_error "Template directory not found: $template_dir"
    return 1
  fi

  # Create package directory
  _mt_log INFO "Creating package: $package_name"
  _mt_log INFO "Location: $package_dir"
  echo ""

  mkdir -p "$package_dir"

  # Copy template files and replace placeholders
  _mt_package_copy_template "$template_dir" "$package_dir" "$package_name"

  # Make bin scripts executable
  if [[ -d "$package_dir/bin" ]]; then
    find "$package_dir/bin" -type f -exec chmod +x {} \;
  fi

  echo ""
  _mt_log INFO "✅ Package '$package_name' created successfully"
  echo ""
  echo "Next steps:"
  echo "  1. cd $package_dir"
  echo "  2. Edit README.md and complete TODO items"
  echo "  3. Optionally rename SKILL.md.example to SKILL.md and customize"
  echo "  4. Add your code to bin/, shell/, config/, or lib/"
  echo "  5. Install with: mt install <module>/$package_name"
  echo ""
}

# Copy template files and replace placeholders
_mt_package_copy_template() {
  local template_dir="$1"
  local package_dir="$2"
  local package_name="$3"

  # Convert package name to title case for display
  local package_title=$(echo "$package_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  # Copy all files from template, replacing placeholders
  (cd "$template_dir" && find . -type f) | while IFS= read -r file; do
    local src="${template_dir}/${file#./}"
    local dest="${package_dir}/${file#./}"

    # Create directory if needed
    mkdir -p "$(dirname "$dest")"

    # Copy file and replace placeholders
    sed \
      -e "s/{PACKAGE_NAME}/${package_name}/g" \
      -e "s/{PACKAGE_TITLE}/${package_title}/g" \
      -e "s/{MODULE}/module/g" \
      "$src" > "$dest"

    _mt_log DEBUG "Created: ${file#./}"
  done

  # Rename package-name placeholder in config path
  if [[ -d "$package_dir/config/dot-config/package-name" ]]; then
    mv "$package_dir/config/dot-config/package-name" \
       "$package_dir/config/dot-config/$package_name"
  fi
}
