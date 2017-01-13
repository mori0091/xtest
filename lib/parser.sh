#!/bin/sh
# -*- coding: utf-8-unix -*-

TAB='	'
NEWLINE='
'

__line__=0
__file__=;

BUFFER=;
X=;
TRY=;

p_init ()
{
    __file__="${1}";
    __line__=0;

    X=;
    BUFFER=;
}

syntax_error ()
{
    echo "$(basename $0): syntax error: ${__file__}:${__line__}: ${@}"
    echo
    exit 2
} >&2

unexpected ()
{
    [ ":${TRY}" != ':' ] && return 1
    syntax_error "Unexpected ${@}"
}

expects ()
{
    [ ":${TRY}" != ':' ] && return 1
    syntax_error "Expects ${@}"
}

try ()
{
    local TRY;
    TRY="${X}:"
    X=;
    "${@}"
    if [ $? -eq 0 ] ; then
	X="${TRY%?}${X}"
	return 0
    else
	BUFFER="${X}${BUFFER}"
	X="${TRY%?}"
	return 1
    fi
}

any ()
{
    while try "${@}" ; do
	true
    done
}

many ()
{
    "${@}" ; try any "${@}"
}

__readline_raw ()
{
    local line
    local IFS
    IFS=''
    read -r line || return
    __line__=$(( __line__ + 1 ))
    BUFFER="${BUFFER}${line}${NEWLINE}"
}

_readline_raw ()
{
    __readline_raw || unexpected eof
}

p_eof ()
{
    [ ':' = ":${BUFFER}" ] && ! __readline_raw || expects eof || return
}

p_a_char ()
{
    [ "${BUFFER}" ] || _readline_raw || return
    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}
    BUFFER="${xs}"
    X="${x}"
}

p_char ()
{
    p_a_char || return
    [ "${1}:" = "${X}:" ] || expects "'${1}' but was '${X}'"
}

p_except ()
{
    p_a_char || return
    [ "${1}:" != "${X}:" ] || unexpected "'${1}'"
}

p_one_of ()
{
    local xs
    local x
    xs="${1:?}"
    x=;
    while [ ${#xs} -gt 0 ] ; do
	x=${xs%"${xs#?}"}
	xs=${xs#?}
	try p_char "${x}" && return
    done
    expects "one of '${1}' but was not"
}

p_none_of ()
{
    local xs
    local x
    xs="${1:?}"
    x=;
    p_a_char || return
    while [ ${#xs} -gt 0 ] ; do
	x=${xs%"${xs#?}"}
	xs=${xs#?}
	[ "${X}:" != "${x}:" ] || unexpected "'${x}'" || return
    done
}

p_spaces ()
{
    p_one_of " ${TAB}"
}

apply ()
{
    local x
    x="${X}"; X=;
    "${@}" "${x}" || syntax_error "Failed to apply ${@} '${x}'"
}

_print ()
{
    apply printf "${@}"
}
