#!/bin/sh
# -*- coding: utf-8-unix -*-

[ "${_UTILS_SH_}" ] && return

readonly _UTILS_SH_=1

is_a_tty ()
{
    [ -t "${1:-2}" ]
}

is_a_color_tty ()
{
    [ ":${COLOR}" = ':always' ] && return 0
    [ ":${COLOR}" = ':never' ]  && return 1
    is_a_tty "${1}" || return
    case "${TERM}" in
	xterm )
	    true ;;
	* )
	    false ;;
    esac
}

color ()
{
    if is_a_color_tty ; then
	_color "${@}"
    else
	shift
	printf '%s' "${*}"
    fi
}

bold ()
{
    if is_a_color_tty ; then
	_bold "${@}"
    else
	printf '%s' "${*}"
    fi
}

# \usage _color COLOR STRING...
_color ()
{
    local col
    local x
    col="${1}"
    shift
    case "${col}" in
	k | black   ) x='30' ;;
	r | red     ) x='31' ;;
	g | green   ) x='32' ;;
	y | yellow  ) x='33' ;;
	b | blue    ) x='34' ;;
	m | magenta ) x='35' ;;
	c | cyan    ) x='36' ;;
	w | white   ) x='37' ;;
	K | BLACK   ) x='90' ;;
	R | RED     ) x='91' ;;
	G | GREEN   ) x='92' ;;
	Y | YELLOW  ) x='93' ;;
	B | BLUE    ) x='94' ;;
	M | MAGENTA ) x='95' ;;
	C | CYAN    ) x='96' ;;
	W | WHITE   ) x='97' ;;
	grey | GREY ) x='90' ;;
	*           ) x='39' ;;
    esac
    printf "\33[${x}m%s\33[39m" "${*}"
}

_bold ()
{
    printf "\33[1m%s\33[0m" "${*}"
}
