#!/usr/bin/env bash

# FILENAME: playwright.sh
# AUTHOR: Zachary Krepelka
# DATE: Monday, November 17th, 2025
# ABOUT: Stage Asciinema Casts Programmatically
# ORIGIN: https://github.com/zachary-krepelka/tmux-playwright.git
# UPDATED: Thursday, April 16th, 2026 at 12:45 AM

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
	  -C DIR   where the recording takes place (default: \$PWD)
	  -d NxM   specify terminal [d]imensions (default: 80x24)
	  -f       [f]orcibly overwrite existing output file
	  -s       check [s]tatus of tmux playwright servers

	Documentation:
	  -h  display this [h]elp message and exit
	  -H  read documentation for this script then exit

	Examples
	  bash $program demo.play demo.cast
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
		asciinema cat column cut less pod2text realpath sed sleep tmux
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

curtain_up() {
	tmux -f /dev/null -L recorder new-session -d "
		asciinema rec --cols=$cols --rows=$rows --overwrite '$output' -c '
			tmux -L recording attach'"
}

curtain_down() {
	tmux -L recording kill-server
}

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

# Command-line Argument Parsing ------------------------------------------- {{{1

check_dependencies # must be called before any external command

cols=80
rows=24
force=false
where="${PWD}"

while getopts ':hHC:d:fs' option
do
	case "$option" in
		h) usage; exit 0;;
		H) documentation; exit 0;;
		C)
			if ! test -d "$OPTARG"
			then  error 6 'alternate directory does not exist'
			fi

			where="$(realpath "$OPTARG")"
		;;
		d)
			if [[ $OPTARG =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]
			then
				cols=$(cut -dx -f1 <<< $OPTARG)
				rows=$(cut -dx -f2 <<< $OPTARG)
			else
				error 7 'invalid dimension specifier'
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

tmux -f /dev/null -L recording new-session -d -c "$where" -x $cols -y $rows '
	bash --noprofile --norc --noediting'

source "$input"

sed -i '/\[server exited\]/d' "$output"

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

Tmux Playwright is a bash script that records an asciinema cast
non-interactively in a headless tmux server using an input script to
programmatically specify behavior.  A design goal is to make the process of
recording asciinema casts reproducible and version-controllable by eliminating
human intervention.  Anyone familiar with scripting tmux can use this tool.  All
you have to do is target the recording in the playscript:

	tmux -L recording send-keys 'echo hello world'

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

Several quality-of-life functions are exposed to the playscript.  Only
C<curtain_up> and C<curtain_down> are mandatory.

=over

=item curtain_up

This function starts the recording.  The region of code prior to the call to
this function runs I<behind the scenes> and may be used to I<set the stage> for
the recording by pre-configuring the environment.

=item curtain_down

This function ends the recording.  The region of code after the call to this
function runs I<behind the scenes> and may be used to perform clean up
operations.  For example, if the recording entailed creating a file, you may
want to delete it afterwards.

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

=item 6 if the argument to B<-C> is not a directory

=item 7 if -d received invalid terminal dimensions. Aim for a string like 80x24.

=back

=head1 EXAMPLES

Create a file with the following contents.  Call it C<example.play>.

	+-----+------------------------------+
	|     | File: example.play           |
	+-----+------------------------------+
	|  1  | curtain_up                   |
	|  2  | typewrite 'echo hello world' |
	|  3  | enter                        |
	|  4  | sleep 1                      |
	|  5  | curtain_down                 |
	+-----+------------------------------+

This file specifies a course of actions.  It is like a playscript for a
theatrical performance because it instructs a future actor on how to perform.
By itself, this is not very interesting.

This program gives life to your playscript.

	bash playwright.sh example.play example.cast

This will output C<example.cast>.  You can play it with this command.

	asciinema play example.cast

=head1 AUTHOR

Zachary Krepelka L<https://github.com/zachary-krepelka>

=cut
