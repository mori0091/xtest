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
    _bind_ "${@}"
}

# ----

_bind_ ()
{
    if [ $# -gt 0 ] ; then
	eval "${@}"
    fi
}

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

_peek_ ()
{
    if [ ${#BUFFER} -eq 0 ] ; then
	_readline_ || {
	    unexpected "eof"
	    return 1
	}
    fi

    eval ${1}=\${BUFFER%\"\${BUFFER#?}\"}\;
}

_consume_ ()
{
    local x xs
    xs=${BUFFER#?}
    x=${BUFFER%"${xs}"}

    BUFFER="${xs}"
    CONSUMED="${CONSUMED}${x}"
    __col__=$(( __col__ + 1 ))
    RESULT="${x}"
}

# ----
# try PARSER
# many PARSER
# many1 PARSER
# PARSER1 and PARSER2
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
    [ ${#1} -gt 0 ] || __error__ "try PARSER"

    CONSUMED=;
    TRY=$(( TRY + 1 ))
    if eval "${1}" ; then
	TRY=$(( TRY - 1 ))
    else
	TRY=$(( TRY - 1 ))
	BUFFER="${CONSUMED}${BUFFER}"
	CONSUMED=;
	RESULT=;
	return 1
    fi
    shift
    _bind_ "${@}"
}

many ()
{
    [ ${#1} -gt 0 ] || __error__ "many PARSER"

    try "${1}" and many "${1}"
    shift
    _bind_ "${@}"
}

many1 ()
{
    [ ${#1} -gt 0 ] || __error__ "many1 PARSER"

    ${1} || return
    and many "${1}"
    shift
    _bind_ "${@}"
}

# ----

unexpected ()
{
    [ ${TRY} -gt 0 ] || __syntax_error__ "Unexpected <${*}>"
    return 1
}

eof ()
{
    { [ ${#BUFFER} -eq 0 ] && ! _readline_ ; } || {
	unexpected ${BUFFER%${BUFFER#?}}
	return 1
    }
    _bind_ "${@}"
}

anyChar ()
{
    local x
    _peek_ x || return
    _consume_
    _bind_ "${@}"
}

except ()
{
    [ ${#1} -eq 1 ] || __error__ "p_except CHAR"

    local x
    _peek_ x || return
    [ ":${1}" != ":${x}" ] || { unexpected "${x}"; return 1; }
    _consume_
    shift
    _bind_ "${@}"
}

char ()
{
    [ ${#1} = 1 ] || __error__ "p_char CHAR"

    local x
    _peek_ x || return
    [ ":${1}" = ":${x}" ] || { unexpected "${x}"; return 1; }
    _consume_
    shift
    _bind_ "${@}"
}

oneOf ()
{
    [ ${#1} -gt 0 ] || __error__ "p_oneOf CHARS"

    local x
    _peek_ x || return

    local ys zs
    ys="${1}"
    while [ ${#ys} -gt 0 ] ; do
	zs=${ys#?}
	if [ ":${x}${zs}" = ":${ys}" ] ; then
	    _consume_
	    shift
	    _bind_ "${@}"
	    return $?
	fi
	ys="${zs}"
    done
    unexpected "${x}"
    return 1
}

noneOf ()
{
    [ ${#1} -gt 0 ] || __error__ "p_noneOf CHARS"

    local x
    _peek_ x || return

    local ys zs
    ys="${1}"
    while [ ${#ys} -gt 0 ] ; do
	zs=${ys#?}
	if [ ":${x}${zs}" = ":${ys}" ] ; then
	    unexpected "${x}"
	    return 1
	fi
	ys="${zs}"
    done
    _consume_
    shift
    _bind_ "${@}"
}

# ----

and ()
{
    [ $? -eq 0 ] || return
    local _x _xs
    as _x
    _bind_ "${@}" || return
    as _xs
    RESULT="${_x}${_xs}"
}

or ()
{
    __error__ "PARSER1 or PARSER2 (not implemented yet)"
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
}

as ()
{
    [ $# -eq 1 ] || __error__ "as VAR"
    eval "${1}=\"\${RESULT}\";"
}

# ----

quoted_string ()
{
    quote and many except_quote and quote || return
    _bind_ "${@}"
}

quote ()
{
    local q
    q="'"
    char "${q}" || return
    _bind_ "${@}"
}

except_quote ()
{
    local q
    q="'"
    except "${q}" || return
    _bind_ "${@}"
}

space ()
{
    oneOf " ${TAB}" || return
    _bind_ "${@}"
}

newline ()
{
    char "${NEWLINE}" || return
    _bind_ "${@}"
}

except_newline ()
{
    except "${NEWLINE}" || return
    _bind_ "${@}"
}

line ()
{
    many except_newline and newline || return
    _bind_ "${@}"
}

identifier ()
{
    alpha_ and many alnum_ || return
    _bind_ "${@}"
}

alpha_ ()
{
    oneOf "${atoz}${AtoZ}_" || return
    _bind_ "${@}"
}

alnum_ ()
{
    oneOf "${atoz}${AtoZ}${decdigit}_" || return
    _bind_ "${@}"
}
