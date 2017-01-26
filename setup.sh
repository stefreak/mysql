#!/bin/bash
set -e -o pipefail

help() {
    echo
    echo 'Usage ./setup.sh ~/path/to/MANTA_PRIVATE_KEY'
    echo
    echo 'Checks that your Triton and Docker environment is sane and configures'
    echo 'an environment file to use.'
    echo
    echo 'MANTA_PRIVATE_KEY is the filesystem path to an SSH private key'
    echo 'used to connect to Manta for the database backups.'
    echo
    echo 'Additional details must be configured in the _env file, but this script will properly'
    echo 'encode the SSH key details for use with this MySQL image.'
    echo
}

# ---------------------------------------------------
# Top-level commands

# Check for correct configuration and setup _env file
envcheck() {
    # setup environment file
    if [ ! -f "_env" ]; then
        echo '# Environment variables for MySQL service' > _env
        echo 'MYSQL_USER=dbuser' >> _env
        echo 'MYSQL_PASSWORD='$(cat /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 7) >> _env
        echo 'MYSQL_REPL_USER=repluser' >> _env
        echo 'MYSQL_REPL_PASSWORD='$(cat /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 7) >> _env
        echo 'MYSQL_DATABASE=demodb' >> _env

        echo 'CONSUL=consul' >> _env
        echo >> _env

        echo 'Edit the _env file with your desired MYSQL_* and MANTA_* config'
    else
        echo 'Existing _env file found, exiting'
        exit
    fi
}

get_root_password() {
    echo $(docker logs ${COMPOSE_PROJECT_NAME:-mysql}_mysql_1 2>&1 | \
               awk '/Generated root password/{print $NF}' | \
               awk '{$1=$1};1'
        ) | pbcopy
}



# ---------------------------------------------------
# parse arguments

# Get function list
funcs=($(declare -F -p | cut -d " " -f 3))

until
    if [ ! -z "$1" ]; then
        # check if the first arg is a function in this file, or use a default
        if [[ " ${funcs[@]} " =~ " $1 " ]]; then
            cmd=$1
            shift 1
        else
            cmd="envcheck"
        fi

        $cmd "$@"
        if [ $? == 127 ]; then
            help
        fi

        exit
    else
        envcheck
    fi
do
    echo
done
