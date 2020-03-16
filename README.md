A tool for finding the pub constraints for Dart package dependencies. Save from
having to manually count up the right number of directories for path overrides,
or remembering the syntax for a git dependency. It can also find the latest
published version of a package on pub and provide a carrot constraint.

This tool _prints_ the constraints, it does not edit a pubspec file directly. It
is designed to be invoked from an editor capable of inserting the output of a
command into the file.

# Installation

```sh
pub global activate -s git git://github.com/natebosch/dartdeps.git
```

Move to a parent directory of your Dart projects. This may be your home
directory. Run `dartdeps scan` to write a `.dartpackages` manifest file which
describes the location of all local Dart packages under that directory. The
manifest file is required for `local` or `git` dependencies. Whenever you add a
new Dart package the scan must be performed again.

# Supported dependency types

## latest

Finds the latest version of a package published to pub and emits a carrot
constraint. The patch version is stripped to follow best practices for
dependencies.

- `dartdeps latest <package>`

## local

Finds a local, relative, path dependency for a given package. The package must
be present in a `.dartpackages` file in a directory somewhere above the working
directory.

- `dartdeps local <package>`

## git

Finds the URL, path, and ref, for a package on github. The package must be in
the `dart-lang` or `google` org. The package must be present in a
`.dartpackages` file in a directory somewhere above the working directory.

- `dartdeps git <package>`
- `dartdeps git <pacakge> <ref>`

# Running from a directory other than a package root

If the current working directory is not the root of the package for the pubspec
you are editing, specify `--from=path/to/pubspec.yaml` for the package to get
correct relative paths.

# Editor Integration

The `dartdeps replace` command reads a string from stdin in the format
`<package>: <type>` and prints the pub constraint. The `git` dependency type
supports defining a ref (branch, tag, sha) in the format `git@<ref>`.

To use this, write a line like one of the following:

```yaml
  test: latest
  test: local
  test: git
  test: git@null_safety
```

Then use your editor to pipe the line through `dartdeps replace`.

## Vim

See `:help read!` and `:help filter`.

Suggested mappings:

```viml
nnoremap <leader>dl :read! dartdeps --from=% local<space>
nnoremap <leader>dp :read! dartdeps latest<space>
nnoremap <leader>dg :read! dartdeps git<space>
nnoremap <leader>dr :.! dartdeps --from=% replace<cr>
xnoremap <leader>dr !dartdeps --from=% replace<cr>
```

Use `<leadr>dl` or `<leader>dp` then type the name of a package and hit
`<enter>` to insert a local path constraint, or a pub carrot constraint for that
package below the cursor. Use `<leader>dg` then type the name of a package, and
optionally a git ref, and hit `<enter>` to insert a git constraint for that
package below the cursor.

Use `<leader>dr` to pipe the current line through `dartdeps replace` from normal
mode, or from visual mode. When used in visual mode with multiple lines selected
only the first line is consider for the new dependency, but all lines are
replaced.

## VSCode

Install the [EditWithShell extension][EditWithShell]. Suggested settings:

```json
{
  "editWithShell.favoriteCommands": [
    {"id": "dartdeps-replace", "command": "dartdeps replace"},
  ],
  "editWithShell.quickCommand1":  "dartdeps-replace",
}
```

Suggested keymaps:

```json
{
  "key": "ctrl+d ctrl+r",
  "command": "editWithShell.runQuickCommand1",
  "when": "editorTextFocus && !editorReadonly"
}
```

Select a line like `  test: local` and hit `ctrl+d ctrl+r` to replace it with an
appropriate local path dependency for the test package.

[EditWithShell]: https://marketplace.visualstudio.com/items?itemName=ryu1kn.edit-with-shell
