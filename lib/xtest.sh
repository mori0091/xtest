#!/bin/sh
# -*- coding: utf-8-unix -*-

[ "${_XTEST_SH_}" ] && return

readonly _XTEST_SH_=1

. utils.sh
. task.sh

_XTEST_SUITE_=;

NEWLINE='
'

_xtest_syntax_error_ ()
{
    trap - 0
    echo "*** xtest : syntax error"
    echo "***         ${@}"
    case "${1}" in
	xtest )
	    echo "*** usage : xtest TEST_NAME : COMMAND [ARGS]"
	    echo "***         xtest TEST_NAME : < SCRIPT"
	    ;;
	* )
	    ;;
    esac
    exit 2
} 1>&2

_xtest_enc ()
{
    printf '%s' "${*}" | base64 --wrap=0
}

_xtest_dec ()
{
    printf '%s' "${1}" | base64 --wrap=0 -d
}

_XTEST_DATASET_=;
_XTEST_DATA_RECORDS_=;
_XTEST_DATA_PARAMS_=;
_XTEST_DATA_CONSTS_=;

data ()
{
    [ $# -eq 1 ] || _xtest_syntax_error_ data "'${@}'"

    local DESCRIPTION
    local DESCRIPTION_BASE64
    local RECORDS
    local RECORDS_BASE64
    local ENTRY

    DESCRIPTION="${*}"
    RECORDS="$(cat -)"

    DESCRIPTION_BASE64="$(_xtest_enc "${DESCRIPTION}")"
    RECORDS_BASE64="$(_xtest_enc "${RECORDS}")"
    
    ENTRY="${DESCRIPTION_BASE64} ${RECORDS_BASE64}"
    
    if [ "${_XTEST_DATASET_}" ] ; then
	_XTEST_DATASET_="${_XTEST_DATASET_}${NEWLINE}${ENTRY}"
    else
	_XTEST_DATASET_="${ENTRY}"
    fi
}

is_identifier ()
{
    [ "${1}" ] || return
    if [ ":${1}" = ":_" ] && [ "${BASH_VERSION}" ] ; then
	_xtest_syntax_error_ Illegal identifier - "'_' is a special parameter in 'bash'"
    fi

    local xs
    xs="${1}"
    case "${xs}" in
	[_a-zA-Z]* )
	    _is_identifier ${xs#?}
	    ;;
	* )
	    return 1
	    ;;
    esac
}

_is_identifier ()
{
    local xs
    xs="${1}"
    while [ ${#xs} -gt 0 ] ; do
	case "${xs}" in
	    [_0-9a-zA-Z]* )
		xs=${xs#?}
		;;
	    * )
		return 1
		;;
	esac
    done
}

with ()
{
    [ $# -gt 2 ] && [ ":${2}" = ':as' ] ||  _xtest_syntax_error_ with "${@}"

    local DESCRIPTION
    local DESCRIPTION_BASE64
    local RECORDS
    local RECORDS_BASE64
    local PARAMS
    DESCRIPTION="${1}"
    DESCRIPTION_BASE64="$(_xtest_enc "${DESCRIPTION}")"
    while read k v ; do
	[ "${k}" ] || _xtest_syntax_error_ with '*** fatal error ***'
	[ "x${k}" = "x${DESCRIPTION_BASE64}" ] || continue
	RECORDS_BASE64="${v}"
	RECORDS="$(_xtest_dec "${RECORDS_BASE64}")"
	break
    done <<-EOF
	${_XTEST_DATASET_}
	EOF
    [ "${RECORDS}" ] || _xtest_syntax_error_ with "No such data - '${DESCRIPTION}'"
    
    shift 2
    PARAMS=;
    while [ $# -gt 0 ] ; do
	is_identifier "${1}" || _xtest_syntax_error_ with "'${DESCRIPTION}'" as "${PARAMS} ${@}"
	if [ "${PARAMS}" ] ; then
	    PARAMS="${PARAMS} ${1}"
	else
	    PARAMS="${1}"
	fi
	shift
    done
    _XTEST_DATA_RECORDS_="${RECORDS}"
    _XTEST_DATA_PARAMS_="${PARAMS}"
    _XTEST_DATA_CONSTS_=;
}

_xtest_argments_def ()
{
    local var
    local val
    for var in ${_XTEST_DATA_PARAMS_} ; do
	eval "val=\"\${${var}}\""
	printf '%s\n' "local ${var}; ${var}=\"${val}\";"
    done
}

# \usage xtest TEST_NAME : COMMAND [ARGS]
# \usage xtest TEST_NAME : < SCRIPT
xtest ()
{
    if [ "${_XTEST_DATA_RECORDS_}" ] ; then
	xtest_dd "${@}"
    else
	xtest_simple "${@}"
    fi
}

xtest_dd ()
{
    [ $# -ge 2 ] && [ "x${2}" = 'x:' ] || _xtest_syntax_error_ xtest "${@}"

    local DATA_INDEX

    local TEST_NAME
    local NAME
    local CODE
    
    NAME="${1}"
    shift 2

    if [ $# -gt 0 ] ; then
	CODE="${@}"
    else
	CODE="$(cat -)"
    fi

    NAME="$(printf '%s' "${NAME}" | sed -r 's/([" 	])/\\\1/g')"
    DATA_INDEX=1
    while read ${_XTEST_DATA_PARAMS_} ; do
	eval "TEST_NAME=\"${NAME}\";"
	xtest_simple "${TEST_NAME}" : <<-EOF
	local DATA_INDEX; DATA_INDEX=${DATA_INDEX};
	$(_xtest_argments_def)
	${CODE}
	EOF
	DATA_INDEX=$((DATA_INDEX + 1))
    done <<-EOF
	${_XTEST_DATA_RECORDS_}
	EOF

    _XTEST_DATA_RECORDS_=;
    _XTEST_DATA_PARAMS_=;
    _XTEST_DATA_CONSTS_=;
}

xtest_simple ()
{
    [ $# -ge 2 ] && [ "x${2}" = 'x:' ] || _xtest_syntax_error_ xtest "${@}"

    local TEST_NAME
    local CODE
    
    TEST_NAME="${1}"
    shift 2

    if [ $# -gt 0 ] ; then
	CODE="${@}"
    else
	CODE="$(cat -)"
    fi

    local F
    local C
    F="_func_$( _xtest_dgst_ "${TEST_NAME}" "${CODE}" )"
    C="$( _xtest_gen_func_def_ "${F}" "${CODE}" )"
    eval "${C}"

    local RECORD
    RECORD="#{${TEST_NAME}}: ${F}"
    if [ "${_XTEST_SUITE_}" ] ; then
	_XTEST_SUITE_="${_XTEST_SUITE_}${NEWLINE}${RECORD}"
    else
	_XTEST_SUITE_="${RECORD}"
    fi
}

_xtest_dgst_ ()
{
    printf '%s' "${*}" | sha256sum | sed -nr 's/^([0-9a-f]+).*$/\1/p'
}

_xtest_gen_func_def_ ()
{
    local FUNC
    local CODE
    FUNC="${1}"
    CODE="${2}"
    cat <<-EOF
	${FUNC} ()
	{
	    local TEST_NAME
	    local TEST_ERR
	    unset -f "${FUNC}"
	    trap ':' INT
	    TEST_NAME="${TEST_NAME}"
	    TEST_ERR="\$( { ${CODE} ; } 2>&1 >/dev/null )"
	    _xtest_error_report \$?
	}
	EOF
}

_xtest_error_report ()
{
    local status
    local errcode
    local errtype
    trap ':' INT
    status="${1}"
    errcode="$(printf '[%3d]' "${status}")"
    [ ${status} -eq 0 ] || {
	if [ ${status} -eq 1 ] ; then
	    errtype="$(color R "NG      ")"
	elif [ ${status} -ge 128 ] ; then
	    errtype="$(color C "CANCELED")"
	else
	    errtype="$(color Y "ERROR   ")"
	fi
	printf "$(bold "${ITEM} %-40s %20s ${errtype}\n")" "${TEST_NAME}" "${errcode}"
	echo "${TEST_ERR:-(no error message)}" | sed 's/^/     | /g'
	echo
    }
    return ${status}
} 1>&2

# \brief Opens an anonymous temporal file for reading and writing.
# \usage _xtest_tempfile [OPTION] [TEMPLATE]
# 
# Use the file descriptor 4 for reading, and 5 for writing.
# 
# \see   mktemp(1)
_xtest_tempfile ()
{
    local tmp
    local ret
    tmp="$(mktemp -q "${@}")" && exec 4<"${tmp}" 5>"${tmp}"
    ret=$?
    rm -f "${tmp}"
    return ${ret}
}

xtest_runtest ()
{
    trap - EXIT
    trap ':' INT
    
    local status
    local testsuite

    readonly testsuite="${_XTEST_SUITE_}"

    # open temp file for recording error report
    _xtest_tempfile -p "${TMPDIR:-.}"
    # tests all testcase in the testsuite
    do_command_tasks 'Testing...' parallel >/dev/null 3>&5 <<-EOF
	${testsuite}
	EOF
    status=$?
    # replay(i.e. dump) the error report
    { cat <&4 ; echo ; } >&2
    # epilogue
    echo "finished with exit-status ${status}" >&2
    return ${status}
}

# Executes 'xtest_runtest' at exit, unless it was called explicitly.
if [ "${BASH_VERSION}" ] ; then
    trap 'xtest_runtest; exit $?' EXIT
else
    trap 'echo "*** call \"xtest_runtest\" explicitly to run tests ***"; exit 2;' EXIT
fi

# ---- assertion lib. ----

assert ()
{
    [ "${@}" ] && return
    
    echo "$(bold $(color Y "Assertion failed"))"
    case $# in
	3 )
	    echo "  expects $(color G e) ${2} $(color R a)"
	    echo "      but $(color G e) was $(color G ${1})"
	    echo "          $(color R a) was $(color R ${3})"
	    ;;
	* )
	    ;;
    esac
    echo
    false
} >&2
