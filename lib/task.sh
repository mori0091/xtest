#!/bin/sh
# -*- coding: utf-8-unix -*-

[ "${_TASK_SH_}" ] && return

readonly _TASK_SH_=1

# \usage _process_task_list_ BRIEF MODE TASK <RECORDS
# \param BRIEF   A short message or description of the task/task-list.
# \param MODE    Processing mode
#                - s, sequential :: do tasks sequentially. one-by-one, stop on canceled/error.
#                - c, concurrent :: do all tasks even if a task was canceled or caused error.
#                - p, parallel   :: same as 'concurrent'
# \param TASK    A name of shell-function or command.
# \input RECORDS A list of arguments for TASK. Each line of RECORDS should be as follows:
#                ARG [ARG]...
_process_task_list_ ()
{
    local interrupted
    interrupted=0
    trap 'interrupted=1' INT

    local BRIEF
    local MODE
    local TASK
    BRIEF="${1}"
    MODE="${2:-parallel}"
    TASK="${3}"

    local TOTAL
    local FAILURES
    local CANCEL
    local ERRORS
    TOTAL=0
    FAILURES=0
    CANCEL=0
    ERRORS=0

    local OK
    local NG
    local CANCELED
    local ERROR
    local RESULT
    OK='OK'
    NG='NG'
    CANCELED='CANCELED'
    ERROR='ERROR'
    RESULT='%d tasks, %d failures, %d canceled, %d errors'
    
    [ -t 2 ] && {
	BRIEF="$(bold "${BRIEF}")"
	OK="$(color G "$(bold "${OK}")")"
	NG="$(color R "$(bold "${NG}")")"
	CANCELED="$(color C "$(bold "${CANCELED}")")"
	ERROR="$(color Y "$(bold "${ERROR}")")"
	RESULT="$(bold "${RESULT}")"
    }

    case "${MODE}" in
	s | seq | sequential )
	    MODE=1 ;;
	p | par | parallel )
	    MODE=0 ;;
	* )
	    MODE=0 ;;
    esac
    
    local status
    local RECORDS
    local RECORD
    local INDEX
    local ITEM
    local TASK_NAME
    local TASK_STATE

    RECORDS="$( sed -nr 's/^(.+)$/\1/p' | cat -n )"
    TOTAL="$(echo "${RECORDS}" | wc -l)"
    
    printf "${BRIEF}\n" >&2
    
    exec <<-EOF
	${RECORDS}
	EOF
    while read INDEX RECORD ; do
	if [ ${interrupted} -eq 1 ] ; then
	    CANCEL=$((CANCEL + TOTAL - INDEX + 1))
	    break
	fi
	ITEM="$( printf "(%${#TOTAL}d/%-${#TOTAL}d)" "${INDEX}" "${TOTAL}" )"
	ITEM="$( printf "%9s" "${ITEM}")"
	TASK_NAME=''
	TASK_STATE=''
	print_task_progress
	( ${TASK} "${RECORD}" )
	status=$?
	if [ ${status} -eq 0 ] ; then
	    printf "${OK}\n" >&2
	elif [ ${status} -eq 1 ] ; then
	    printf "${NG}\n" >&2
	    FAILURES=$((FAILURES + 1))
	elif [ ${status} -ge 128 ] ; then
	    printf "${CANCELED}\n" >&2
	    CANCEL=$((CANCEL + 1))
	else
	    printf "${ERROR}\n" >&2
	    ERRORS=$((ERRORS + 1))
	fi

	if [ ${status} -ne 0 ] && [ ${MODE} -eq 1 ] ; then
	    interrupted=1
	else
	    interrupted=0
	fi
    done

    local PASSED
    PASSED=$(( TOTAL - FAILURES - CANCEL - ERRORS ))
    printf "${RESULT}\n" ${TOTAL} ${FAILURES} ${CANCEL} ${ERRORS} >&2
    echo >&2
    
    [ ${TOTAL} -eq ${PASSED} ]
}

print_task_progress ()
{
    printf "\33[G\33[K"
    printf "${ITEM} %-40s %20s " "${TASK_NAME}" "${TASK_STATE}"
} >&2

# \usage do_command_tasks BRIEF MODE <RECORDS
# \param BRIEF   A short message or description of the task-list.
# \param MODE    Processing mode
#                - s, sequential :: do tasks sequentially. one-by-one, stop on canceled/error.
#                - c, concurrent :: do all tasks even if a task was canceled or caused error.
#                - p, parallel   :: same as 'concurrent'
# \input RECORDS A list of commands. Each line of RECORDS should be as follows:
#                #{NAME}: COMMAND [ARG]...
do_command_tasks ()
{
    _process_task_list_ "${1}" "${2}" _command_task_
}

_command_task_ ()
{
    trap ':' INT
    local RECORD
    local NAME
    local COMMAND
    local status
    # set - ${1}; RECORD="${*}"
    RECORD="${1}"
    COMMAND=${RECORD#'#{'*'}:'}
    NAME=${RECORD%"${COMMAND}"}
    NAME=${NAME#'#{'}
    NAME=${NAME%'}:'}
    [ "#{${NAME}}:${COMMAND}" = "${RECORD}" ] || {
	echo "_command_task_:: parse error - '${RECORD}'" >&3
	return 2
    }
    TASK_NAME="${NAME}"
    print_task_progress
    ( ${COMMAND} ) </dev/null 2>&3

    status=$?
    trap ':' INT
    if [ ${status} = 0 ] ; then
	TASK_STATE='done'
    else
	TASK_STATE="$(printf '[%3d]' "${status}")"
    fi
    print_task_progress
    return ${status}
}
