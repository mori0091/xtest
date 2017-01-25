#!/bin/sh
# -*- coding: utf-8-unix -*-

# DIR="$(cd "$(dirname "${0}")"; pwd)"
# TOP_DIR="$(cd "$(dirname "${DIR}")"; pwd)"
# BIN_DIR="${TOP_DIR}/bin"
# LIB_DIR="${TOP_DIR}/lib"
# TEST_DIR="${TOP_DIR}/test"

# PATH="${PATH}:${BIN_DIR}:${LIB_DIR}"

readonly TAB='	'
readonly NEWLINE='
'
readonly bindigit='01'
readonly octdigit='01234567'
readonly decdigit='0123456789'
readonly hexdigit='0123456789abcdef'
readonly atoz='abcdefghijklmnopqrstuvwxyz'
readonly AtoZ='ABCDEFGHIJKLMNOPQRSTUVWXYZ'

# \usage parse FILEPATH PARSER_FUNC [ARG]... <INPUT
parse ()
{
    local CONSUMED
    local BUFFER
    local __file__
    local __line__
    local __col__
    local RESULT
    local TRY

    CONSUMED=;
    BUFFER=;
    __file__="${1}"
    __line__=0
    __col__=0
    RESULT=;
    TRY=0
    shift
    __bind__ "${@}" 
}

__bind__ ()
{
    if [ $# -gt 0 ] ; then
	eval "${@}"
    fi
}

# ----

__error__ ()
{
    printf "\n"
    printf "error: ${@}\n"
    exit 2
}

__syntax_error__ ()
{
    printf "\n"
    printf "Syntax error:${__file__}:${__line__}:${__col__}\n"
    printf '%s\n' "${*}"
    exit 1
}

# ----

__readline__ ()
{
    local IFS
    IFS=;
    read -r BUFFER && BUFFER="${BUFFER}${NEWLINE}"
    [ ${#BUFFER} -gt 0 ]
}

_readline_ ()
{
    __readline__ || return
    __line__=$(( __line__ + 1 ))
    __col__=0
}

# ----
# try PARSER
# many PARSER
# many1 PARSER
# PARSER1 or PARSER2
# 
# unexpected STRING
# eof
# anyChar
# except CHAR
# char CHAR
# oneOf STRING
# noneOf STRING
# ----

try ()
{
    p_try "${1}" || return
    shift
    __bind__ "${@}"
}

many ()
{
    p_many "${1}" || return
    shift
    __bind__ "${@}"
}

many1 ()
{
    p_many1 "${1}" || return
    shift
    __bind__ "${@}"
}

unexpected ()
{
    p_unexpected "${1}" || return
    shift
    __bind__ "${@}"
}

eof ()
{
    p_eof || return
    __bind__ "${@}"
}

anyChar ()
{
    p_anyChar || return
    __bind__ "${@}"
}

except ()
{
    p_except "${1}" || return
    shift
    __bind__ "${@}"
}

char ()
{
    p_char "${1}" || return
    shift
    __bind__ "${@}"
}

oneOf ()
{
    p_oneOf "${1}" || return
    shift
    __bind__ "${@}"
}

noneOf ()
{
    p_noneOf "${1}" || return
    shift
    __bind__ "${@}"
}

quoted_string ()
{
    p_quoted_string || return
    __bind__ "${@}"
}

# ----

p_unexpected ()
{
    [ ${TRY} -gt 0 ] || __syntax_error__ "Unexpected <${*}>"
    return 1
}

p_try ()
{
    [ ${#1} -gt 0 ] || return

    local ___CONSUMED___
    ___CONSUMED___="${CONSUMED}"
    CONSUMED=;
    TRY=$(( TRY + 1 ))
    if eval "${1}" ; then
	TRY=$(( TRY - 1 ))
	CONSUMED="${___CONSUMED___}${CONSUMED}"
	true
    else
	TRY=$(( TRY - 1 ))
	BUFFER="${CONSUMED}${BUFFER}"
	CONSUMED="${___CONSUMED___}"
	false
    fi
}

p_many ()
{
    [ ${#1} -gt 0 ] || __error__ "p_many PARSER"
    
    local x
    x=;
    while p_try "${1}" ; do
	x="${x}${RESULT}"
    done
    RESULT="${x}"
}

p_many1 ()
{
    [ ${#1} -gt 0 ] || __error__ "p_many1 PARSER"

    eval "${1}" || return
    local x
    x="${RESULT}"
    while p_try "${1}" ; do
	x="${x}${RESULT}"
    done
    RESULT="${x}"
}

p_eof ()
{
    { [ ${#BUFFER} -eq 0 ] && ! _readline_ ; } || {
	p_unexpected ${BUFFER%${BUFFER#?}}
	return 1
    }
}

p_anyChar ()
{
    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    p_unexpected "eof"
	    return 1
	}
    fi

    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    CONSUMED="${CONSUMED}${x}"
    BUFFER="${xs}"
    __col__=$(( __col__ + 1 ))
    RESULT="${x}"
}

p_except ()
{
    [ ${#1} -eq 1 ] || return

    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    p_unexpected "eof"
	    return 1
	}
    fi

    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    [ ":${1}" != ":${x}" ] || { p_unexpected "${x}"; return 1; }

    CONSUMED="${CONSUMED}${x}"
    BUFFER="${xs}"
    __col__=$(( __col__ + 1 ))
    RESULT="${x}"
}

p_char ()
{
    [ ${#1} = 1 ] || __error__ "p_char CHAR"

    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    p_unexpected "eof"
	    return 1
	}
    fi

    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    [ ":${1}" = ":${x}" ] || { p_unexpected "${x}"; return 1; }
    
    CONSUMED="${CONSUMED}${x}"
    BUFFER="${xs}"
    __col__=$(( __col__ + 1 ))
    RESULT="${x}"
}

p_oneOf ()
{
    [ ${#1} -gt 0 ] || __error__ "p_oneOf CHARS"

    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    p_unexpected "eof"
	    return 1
	}
    fi

    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    local ys zs
    ys="${1}"
    while [ ${#ys} -gt 0 ] ; do
	zs=${ys#?}
	if [ ":${x}${zs}" = ":${ys}" ] ; then
	    CONSUMED="${CONSUMED}${x}"
	    BUFFER="${xs}"
	    __col__=$(( __col__ + 1 ))
	    RESULT="${x}"
	    return $?
	fi
	ys="${zs}"
    done
    p_unexpected "${x}"
    return 1
}

p_noneOf ()
{
    [ ${#1} -gt 0 ] || __error__ "p_noneOf CHARS"

    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    p_unexpected "eof"
	    return 1
	}
    fi

    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    local ys zs
    ys="${1}"
    while [ ${#ys} -gt 0 ] ; do
	zs=${ys#?}
	if [ ":${x}${zs}" = ":${ys}" ] ; then
	    p_unexpected "${x}"
	    return 1
	fi
	ys="${zs}"
    done
    CONSUMED="${CONSUMED}${x}"
    BUFFER="${xs}"
    __col__=$(( __col__ + 1 ))
    RESULT="${x}"
}

p_quoted_string ()
{
    local q
    local s
    q="'"
    char "${q}" && many 'except "${q}"' as s && char "${q}" || return
    RESULT="'${s}'"
}

space ()
{
    oneOf " ${TAB}" || return
    __bind__ "${@}"
}

newline ()
{
    char "${NEWLINE}" || return
    __bind__ "${@}"
}

line ()
{
    p_line || return
    __bind__ "${@}"
}

p_line ()
{
    local x
    many 'except "${NEWLINE}"' as x && newline || return
    RESULT="${x}${NEWLINE}"
}

identifier ()
{
    p_identifier || return
    __bind__ "${@}"
}

p_identifier ()
{
    local x
    oneOf "_${atoz}${AtoZ}" as x && many 'oneOf "${decdigit}${atoz}${AtoZ}"' || return
    RESULT="${x}${RESULT}"
}

# ----

show ()
{
    local x
    if [ $# -gt 0 ] ; then
	printf '%s' "${*}"
    else
	printf '%s' "${RESULT}"
    fi
    # RESULT=;
}

as ()
{
    [ $# -eq 1 ] || __error__ "as VAR"
    eval "${1}=\"\${RESULT}\";"
}
