# Nushell functions and aliases
# https://www.nushell.sh/book/aliases.html#persisting

# General "ls -l" command
export def l [...args: glob]: nothing -> nothing {
	# When $args is empty, "ls ...$args" returns nothing
	if ($args | is-empty) {
		ls --long --short-names
			| select name user group mode size modified
			| update name {path basename}
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --long --short-names ...$args
			| select name user group mode size modified
			| update name {path basename}
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}


# General "ls -la" command
export def la [...args: glob]: nothing -> nothing {
	if ($args | is-empty) {
		ls --all --long --short-names
			| select name user group mode size modified
			| update name {path basename}
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --all --long --short-names ...$args
			| select name user group mode size modified
			| update name {path basename}
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}


# "ls -la" command that shows the links
export def ll [...args: glob]: nothing -> nothing {
	if ($args | is-empty) {
		ls --all --long --short-names
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --all --long --short-names ...$args
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}

# "ls -lat" command
export def lt [...args: glob]: nothing -> nothing {
	if ($args | is-empty) {
		ls --all --long --short-names
			| sort-by modified
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --all --long --short-names ...$args
			| sort-by modified
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}


# "ls -lart" command
export def lrt [...args: glob]: nothing -> nothing {
	if ($args | is-empty) {
		ls --all --long --short-names
			| sort-by --reverse modified
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --all --long --short-names ...$args
			| sort-by --reverse modified
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}


# "ls -larS" command
export def lrs [...args: glob]: nothing -> nothing {
	if ($args | is-empty) {
		ls --all --long --short-names
			| sort-by size
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	} else {
		ls --all --long --short-names ...$args
			| sort-by size
			| select name user group mode size modified target
			| update modified {format date "%Y-%m-%d %H:%M:%S"}
			| table --width 999
	}
}


# dl will download a file from a URL
export def dl [url: string, --overwrite (-o)]: nothing -> table<name: string, value: string> {
	use std/log
	let response_headers = (http head $url)
	let content_disposition = ($response_headers | where name =~ 'content-disposition' | get value | parse --regex '.*filename=(?<filename>[^ ]+)')
	mut filename = ""
	if not ($content_disposition | is-empty) {
		# Content-Disposition header might have the filename.
		$filename = ($content_disposition | get filename.0)
	} else {
		if ($url | str ends-with '/') {
			log warning $"URL ends with a path and the HTTP headers do not have a filename. Using a generated filename"
			$filename = $"dl-(random uuid).bin"
		} else {
			$filename = (($url | url parse).path | path basename)
		}
	}
	# "http get" streams the response while "http get --full" buffers the request. Separating the response headers
	# from the body is not possible.
	# https://discordapp.com/channels/601130461678272522/601130461678272524/1209936591267569675
	# "save" refuses to overwrite, and its own hint names a flag this command does not have.
	if ($filename | path exists) {
		if not $overwrite {
			error make {msg: $"'($filename)' already exists. Pass --overwrite to replace it."}
		}
		rm $filename
	}
	http get $url | save --progress $filename
	$response_headers
}

# Alias for a one-line git log.
export def git-log []: nothing -> any {
	git log --oneline --decorate --all --graph --format=oneline
}


# ripgrep all files. Not the same as repgrep-all.
export def rga []: nothing -> any {
	^rg --hidden --no-ignore
}


# fd (find) all files.
export def fda []: nothing -> any {
	^fd --hidden --no-ignore
}


# Get the hash of one or more files.
export def get-hash [...args: glob]: nothing -> table<file: string, hash: string> {
	use std log
	if ($args | is-empty) {
		error make {msg: "No files specified"}
	}
	[...$args] | each {|it|
		log info $"Glob: ($it)"
		glob ($it | into string)
	} | flatten | each {|it|
		{
			file: ($it | path basename),
			hash: (open --raw $it | hash sha256)
		}
	} | sort-by hash
}


# Extract the filename from the URL headers.
export def url-filename []: string -> string {
	let url = $in
	let content_disposition = (
		http head $url
		| where name =~ 'content-disposition'
		| get value
		| parse --regex '.*filename="?(?<filename>[^";]+)[;"]?'
	)

	if not ($content_disposition | is-empty) {
		# Content-Disposition header might have the filename.
		return ($content_disposition | get filename.0)
	} else {
		if ($url | str ends-with '/') {
			use std log
			log warning $"URL ends with a path and the HTTP headers do not have a filename. Using a generated filename"
			return $"dl-(random uuid).bin"
		} else {
			return (($url | url parse).path | path basename)
		}
	}
}


# "git commit --message 'my changes'" with syntactic sugar to pull changes first. This makes conflict resolution
# easier by short circuiting if the pull fails.
export def git-commit [message: string]: nothing -> nothing {
	git pull
	print "---"
	git add --update
	git commit --signoff --message $"($message)"
	print "---"
	git push
}


# Push a new version. Needs the inc plugin: plugin add /usr/local/bin/nu_plugin_inc
export def git-version [
	message: string,
	version: string = "0.0.0"
	--major (-M) = false
	--minor (-m) = false
	--patch (-p) = false
]: nothing -> nothing {
	use std log

	if (which inc | is-empty) {
		error make {msg: "The inc plugin is not registered. Run: plugin add /usr/local/bin/nu_plugin_inc"}
	}

	mut new_version = $version
	let cur_version = (^git describe --tags --abbrev=0)
	if $env.LAST_EXIT_CODE == 0 {
		# Repo already has a tagged version. Use it.
		$new_version = ($cur_version | str replace --regex '^v' '')
	}

	# Increment the version to publish
	if $major {
		$new_version = ($new_version | inc --major)
	} else if $minor {
		$new_version = ($new_version | inc --minor)
	} else {
		$new_version = ($new_version | inc --patch)
	}

	log info $"Publishing version ($new_version)"

	git pull
	git add --update
	git commit --signoff --message $message
	git checkout main
	# FIXME: Determine the branch dynamically.
	git merge develop
	git tag --annotate --message $"Release ($new_version)" $new_version
	git push origin $new_version
	git push
}


# Backup the specified directory to the current directory.
# TODO: Save the backup in another directory.
export def backup [dir: string]: nothing -> nothing {
	# Equivalent tar: ^tar --use-compress-program zstd --create --file <name>.tar.zstd <dir>
	let d = ($dir | path expand | path basename)
	if not ($d | path exists) {
		error make {msg: $"Directory does not exist: '($d)'"}
	}
	ouch compress --format tar.zst $d $"($d)-(date now | format date "%Y%m%dT%H%M%S").tar.zst"
}


# Restore the backup to the current directory.
export def restore [archive: string]: nothing -> nothing {
	ouch decompress $archive
}


# Parse /etc/os-release into a table of name/value pairs.
export def "os-release" []: nothing -> table {
	open /etc/os-release | parse '{name}="{value}"'
}


# Get the mountpoints as a table.
export def "get-mountpoints" []: nothing -> table {
	if (which mount | is-empty) {
		error make {msg: "The 'mount' command is not found. Please install 'mount' and try again."}
	}
	^mount
		| from ssv --minimum-spaces 1
		| rename proc on_word mountpoint type_word options
		| select proc mountpoint options
}


# find_dir will traverse the directories up until it finds the "name"d directory.
export def find-dir-parent [name: string]: [nothing -> string, nothing -> nothing] {
	mut $dir = $env.PWD
	mut $parent_dir = ($dir | path dirname)
	mut $count = 0
	# Maximum number of iterations (directories) before exiting.
	let max_count = 20

	while ($parent_dir != $dir) {
		if ($dir | path join $name | path exists) {
			return ($dir | path join $name)
		}
		$dir = $parent_dir
		$parent_dir = ($parent_dir | path dirname)
		$count += 1
		if ($count > $max_count) {
			print $"Maximum number of iterations reached"
			print $"count: ($count)"
			print $"max_count: ($max_count)"
			return null
		}
	}
	if ($parent_dir == $dir) {
		# Did not find the directory
		return null
	} else {
		# This is an error condition and should not be reached.
		print $"Did not find '($name)' directory in loop, and did not reach root of drive."
		print $"dir: ($dir)"
		print $"parent_dir: ($parent_dir)"
		return null
	}
}


# table-diff will compare the difference between two tables.
export def table-diff [
	left: list<any>,
	right: list<any>,
	--keys (-k): list<string> = [],
] {
	let left = if ($left | describe) !~ '^table' { $left | wrap value } else { $left }
	let right = if ($right | describe) !~ '^table' { $right | wrap value } else { $right }
	let left_selected = ($left | select ...$keys)
	let right_selected = ($right | select ...$keys)
	let left_not_in_right = (
		$left |
		where { |row| not (($row | select ...$keys) in $right_selected) }
	)
	let right_not_in_left = (
		$right |
		where { |row| not (($row | select ...$keys) in $left_selected) }
	)
	(
		$left_not_in_right | insert side '<='
	) ++ (
		$right_not_in_left | insert side '=>'
	)
}
