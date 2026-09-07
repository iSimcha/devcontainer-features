## Define the Starship prompt
## http://www.nushell.sh/book/3rdpartyprompts.html#starship
$env.STARSHIP_SHELL = "nu"

def create_left_prompt [] {
    # starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
    let dir = match (do --ignore-errors { $env.PWD | path relative-to $nu.home-path }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }

	let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
	let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    let path_segment = $"($path_color)($dir)(ansi reset)"

    $path_segment | str replace --all (char path_sep) $"($separator_color)(char path_sep)($path_color)"
}

def create_right_prompt [] {
	# create a right prompt in magenta with green separators and am/pm underlined
	let time_segment = ([
		(ansi reset)
		(ansi magenta)
		(date now | format date '%Y-%m-%d %H:%M:%S')
	]
	| str join
	| str replace --regex --all "([/:])" $"(ansi green)${1}(ansi magenta)"
	| str replace --regex --all "([AP]M)" $"(ansi magenta_underline)${1}"
	)

	let last_exit_code = if ($env.LAST_EXIT_CODE != 0) {
		([
			(ansi rb)
			($env.LAST_EXIT_CODE)
		] | str join)
	} else { "" }

	([$last_exit_code, (char space), $time_segment] | str join)
}

# Use nushell functions to define your right and left prompt
$env.PROMPT_COMMAND = {|| create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = {|| create_right_prompt }

# The prompt indicators are environmental variables that represent
# the state of the prompt
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "〉"
$env.PROMPT_MULTILINE_INDICATOR = "::: "

$env.NU_LIB_DIRS = [
	($nu.default-config-dir | path join 'scripts') # add <nushell-config-dir>/scripts
    ($nu.data-dir | path join 'completions') # default home for nushell completions
	($nu.default-config-dir | path join 'modules')  # default home for nushell modules
]

# https://starship.rs/#nushell
if not (which starship | is-empty) {
	# Starship is installed
	mkdir ($nu.data-dir | path join "vendor/autoload")
	let starship_autoload = ($nu.data-dir | path join "vendor/autoload/starship.nu")
	# Regenerated on every startup, and "save" refuses to overwrite, so drop the stale file first.
	if ($starship_autoload | path exists) { rm $starship_autoload }
	starship init nu | save $starship_autoload
}

use std "path add"
$env.PATH = ($env.PATH | split row (char esep))
path add ($env.HOME | path join ".local" "bin")
path add ($env.HOME | path join ".npm-packages" "bin")
path add ($env.HOME | path join ".bun" "bin")
path add ($env.HOME | path join ".yarn" "bin")
path add ($env.HOME | path join ".cargo" "bin")
path add "/usr/local/bin"
$env.PATH = ($env.PATH | uniq)
