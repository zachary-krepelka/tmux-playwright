#!/usr/bin/env bash

# FILENAME: playwright.sh
# AUTHOR: Zachary Krepelka
# DATE: Monday, November 17th, 2025
# ABOUT: Stage Asciinema Casts Programmatically
# ORIGIN: https://github.com/zachary-krepelka/tmux-bad-apple.git
# UPDATED: Monday, December 1st, 2025 at 10:38 PM

# Functions --------------------------------------------------------------- {{{1

program="${0##*/}"

usage() {
	cat <<-USAGE
	Tmux Playwright - Stage Asciinema Casts Programmatically

	Usage:
	  bash $program [options] <playscript> <recording>

	  <playscript> is input  (it's a bash script)
	  <recording> is output  (it's an asciinema cast)

	Options:
	  -c FILE  pre-[c]onfigure tmux environment before recording
	           FILE is in the tmux configuration language
	  -C DIR   where the recording takes place (default: \$PWD)
	  -d NxM   specify terminal [d]imensions (default: 80x24)
	  -f       [f]orcibly overwrite existing output file
	  -s       check [s]tatus of tmux playwright servers

	Documentation:
	  -h  display this [h]elp message and exit
	  -H  read documentation for this script then exit

	Examples
	  bash $program demo.script demo.cast
	USAGE
}

documentation() {
	pod2text "$0" | less -Sp '^[^ ].*$' +k
}

error() {
	local code="$1" message="$2"
	echo "$program: error: $message" >&2
	exit "$code"
}

check_dependencies() {

	local missing= dependencies=(
		asciinema cat column cut less pod2text realpath sleep tmux
	)

	for cmd in "${dependencies[@]}"
	do
		if ! command -v "$cmd" &>/dev/null
		then missing+="$cmd, "
		fi
	done

	if test -n "$missing"
	then error 1 "missing dependencies: ${missing%, }"
	fi
}

# Exports ----------------------------------------------------------------- {{{1

typewrite() {

	local OPTIND delay=0.05

	while getopts d: option
	do
		case "$option" in
			d) delay="$OPTARG";;
		esac
	done

	shift $((OPTIND - 1))

	local  text="$1" len="${#1}"

	for (( i = 0; i < len; i++ ))
	do
		char="${text:$i:1}"

		test "$char" = ';' && char="\;"

		tmux -L recording send-keys -l "$char"

		sleep $delay
	done
}

enter() {
	tmux -L recording send-keys C-m
}

curtain-call() {
	tmux -L recording kill-server
}

export -f typewrite enter curtain-call

# Command-line Argument Parsing ------------------------------------------- {{{1

check_dependencies # must be called before any external command

cols=80
rows=24
config=
force=false
where="${PWD}"

while getopts ':hHc:C:d:fs' option
do
	case "$option" in
		h) usage; exit 0;;
		H) documentation; exit 0;;
		c)
			if ! test -f "$OPTARG"
			then error 6 'configuration file does not exist'
			fi

			if ! tmux source-file -n "$OPTARG" &> /dev/null
			then error 7 'configuration file contains errors'
			fi

			config="$OPTARG"
		;;
		C)
			if ! test -d "$OPTARG"
			then  error 8 'alternate directory does not exist'
			fi

			where="$(realpath "$OPTARG")"
		;;
		d)
			if [[ $OPTARG =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]
			then
				cols=$(cut -dx -f1 <<< $OPTARG)
				rows=$(cut -dx -f2 <<< $OPTARG)
			else
				error 9 'invalid dimension specifier'
			fi
		;;
		f) force=true;;
		s)
			for server in recorder recording
			do
				echo -n $server ' '
				if tmux -L $server info &> /dev/null
				then echo up
				else echo down
				fi
			done | column -t -N SERVER,STATUS
			exit 0
		;;
		*) error 2 "unknown option -$OPTARG";;
	esac
done

shift $((OPTIND - 1))

if test $# -ne 2
then error 3 'exactly two arguments are required'
fi

input="$1" output="$2"

if ! test -f "$input"
then error 4 'input is not a file'
fi

if ! $force && test -f "$output"
then error 5 'output file exists, use -f to overwrite'
fi

# Main Processing --------------------------------------------------------- {{{1

tmux -f /dev/null -L recording new-session -d -c "$where" -x $cols -y $rows

if test -n "$config"
then tmux -L recording source-file "$config"
fi

tmux -f /dev/null -L recorder new-session -d "
	asciinema rec --cols=$cols --rows=$rows --overwrite '$output' -c '
		tmux -L recording attach'"

bash "$input"

# Documentation ----------------------------------------------------------- {{{1

# https://charlotte-ngs.github.io/2015/01/BashScriptPOD.html
# http://bahut.alma.ch/2007/08/embedding-documentation-in-shell-script_16.html

: <<='cut'
=pod

=head1 NAME

playwright.sh - Stage Asciinema Casts Programmatically

=head1 SYNOPSIS

 bash playwright.sh [options] <playscript> <recording>

 <playscript> is input  (it's a bash script)
 <recording> is output  (it's an asciinema cast)

=head1 DESCRIPTION

This documentation is still under construction.

Tmux Playwright is a bash script that records an Asciinema cast
non-interactively in a headless tmux server using an input script to
programmatically specify behavior.  A design goal is to make the process of
recording Asciinema casts reproducible and version-controllable by eliminating
human intervention.

=head1 OPTIONS

=over

=item B<-h>

Display a [h]elp message and exit.

=item B<-H>

Display this documentation in a pager and exit after the user quits.  The
documentation is divided into sections.  Each section header is matched with a
search pattern, meaning that you can use navigation commands like C<n> and its
counterpart C<N> to go to the next or previous section respectively.

The uppercase -H is to parallel the lowercase -h.

=back

=head1 COMMANDS

Several quality-of-life functions are exposed to the playscript.

=over

=item typewrite [-d <delay>] <text>

This function types text.  This is roughly equivalent to

	tmux -L recording send-keys -l <text>

except that there is a <delay> between sending each character to simulate a user
typing. The default delay is 0.05 seconds.  This function has not been
thoroughly tested, so you may run into problems with certain characters that
need escaped in some special way.

=item enter

This function presses enter.  It is equivalent to

	tmux -L recording send-keys Enter

=item curtain-call

This ends the recording. It is equivalent to

	tmux -L recording kill-server

=back

=head1 DIAGNOSTICS

The program exits with the following status codes.

=over

=item 0 if okay

=item 1 if dependencies are missing

=item 2 if an unknown option is passed

=item 3 if the wrong number of arguments are passed

=item 4 if the input is not a file

=item 5 if the output file already exists

=item 6 if the argument to B<-c> is not a file

=item 7 if the file to B<-c> contains errors, i.e., tmux fails to parse it

=item 8 if the argument to B<-C> is not a directory

=item 9 if -d received invalid terminal dimensions. Aim for a string like 80x24.

=back

=head1 EXAMPLES

Create a file with the following contents.  Call it C<example.script>.

	+-----+------------------------------+
	|     | File: example.script         |
	+-----+------------------------------+
	|  1  | typewrite 'echo hello world' |
	|  2  | enter                        |
	|  3  | sleep 1                      |
	|  4  | curtain-call                 |
	+-----+------------------------------+

This file specifies a course of actions.  It is like a playscript for a
theatrical performance because it instructs a future actor on how to perform.
By itself, this is not very interesting.

This program gives life to your playscript.

	bash playscript.sh example.script example.cast

This will output C<example.cast>.  You can play with this command.

	asciinema play example.cast

=head1 AUTHOR

Zachary Krepelka L<https://github.com/zachary-krepelka>

=cut
