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
