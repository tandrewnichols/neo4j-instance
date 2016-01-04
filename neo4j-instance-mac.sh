#!/bin/bash

bash_version=`echo $BASH_VERSION |sed -e  "s/[^0-9\.]//g"`;

function vercomp {
    if [[ $1 == $2 ]]
    then
	echo "0";
	return 0;
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
	    echo 1;
	    return 1;
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo 2;
	    return 2;
        fi
    done
    echo 0;
    return 0;
}


#versionResults=`vercomp "$bash_version" "4.0"`;
#if [[ "$versionResults" == 2 ]]; then 
    #echo "need bash 4.0 to run properly";
    #exit;
#fi

function usage {
    read -r -d "" output << TXT
Usage: neo4j-instance [command]

The commands are as follows:
 help                           outputs this document
 create [option]                create a new database instance
     options:
        -d <db name>            sets the name of the neo4j instance
        -t <neo4j type>         sets the neo4j type (community | enterprise)
        -v <neo4j version>      sets neo4j version (default: $currentVersion)
 rename-db <port> <db name>     renames the db neo4j instance
 start <port>                   starts a neo4j instance
 stop <port>                    stops a neo4j instance
 destroy <port>                 destroys a database instance
 shell <port>                   allows you to enter in shell mode
 list                           list the different databases,
                                with their ports and their statuses
 plugin list [port]             list the available plugins for neo4j
 plugin install <alias> <port>  installs a plugin
 plugin install <alias> <port>  remove a plugin

Report bugs to levi@eneservices.com
TXT
    echo "$output";
    exit 1;
}

function setup {
    if [ "$username" == 'root' ]; then
        message "script should not be ran as root" "W" $red;
        exit;
    fi

    if [ -d ~/neo4j-instances ]; then
        cd ~/neo4j-instances
    else
        cd ~;
        mkdir neo4j-instances;
        cd ~/neo4j-instances;
    fi

    if [ ! -d ports ]; then
        mkdir ports;
    fi
}

function portIsTaken {
    port=$1;
    if (netstat -tulpn 2>&1 | sed -e 's/\s\+/ /g' | cut -d " " -f4 >&1 | grep ":$port$" > /dev/null); then
        return 0;
    fi
    return 1;
}

function databaseExists {
    if grep "^$1\$" ports/*/db-name > /dev/null 2>&1; then
        return 0;
    fi
    return 1;
}

function message {
    message=$1
    tag=$2
    color=$3

    if [ ! -z "$tag" ]; then
      tag="*${color}$tag${nocolor}* ";
    fi

    echo -e "$tag$message";
}

function createDatabase {
    dbName="";
    lastShellPort=$startShellPort;
    lastPort=$(ls ports | sort | tail -n1);
    lastSslPort=$((lastPort - 1));

    if [ -z "$lastPort" ]; then
        lastPort="$startPort";
        lastSslPort=$((lastPort - 1));
    fi

    if [ -d "ports/$lastPort" ]; then
        while [ -d "ports/$lastPort" ]; do
            lastShellPort=$(cat ports/$lastPort/shell-port);
            lastPort=$((lastPort + 2));
            if ( ! portIsTaken $((lastShellPort + 1)) ); then
                lastShellPort=$((lastShellPort + 1));
            fi
        done
        lastSslPort=$((lastPort-1));
    fi

    OPTIND=2;
    # set neo4j type and version
    while getopts "d:t:v:" o; do
        case "$o" in
            d) if  databaseExists "$OPTARG"; then
                message "database name is already taken" "E" $red;
                exit;
            fi
            dbName=$OPTARG;
            ;;
        t) type=$OPTARG;
            (( "$type" == "community" || "$type" == "enterprise")) && neo4jType=$type;
            ;;
        v) version=$OPTARG;
            if [[ $version =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
                currentVersion=$version
            fi
            ;;
        *) usage;
            ;;
        esac
    done

    if [ ! -d "neo4j-skeleton/${neo4jType}-${currentVersion}" ]; then
        mkdir -p "./neo4j-skeleton/${neo4jType}-${currentVersion}";
        if hash curl; then
            curl -# -L "http://neo4j.com/artifact.php?name=neo4j-${neo4jType}-${currentVersion}-unix.tar.gz" | tar xzC "neo4j-skeleton/${neo4jType}-${currentVersion}/" --strip-components 1
        elif hash wget; then
            wget -O- "http://neo4j.com/artifact.php?name=neo4j-${neo4jType}-${currentVersion}-unix.tar.gz" | tar xzC "neo4j-skeleton/${neo4jType}-${currentVersion}/" --strip-components 1
        else
            message "please install curl or wget" "W" $blue;
            exit;
        fi
    fi

    if [ ! -d "ports/$lastPort" ]; then
        message "create database" "X" $green;
        cp -r "neo4j-skeleton/${neo4jType}-${currentVersion}" "ports/$lastPort";
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j-server.properties" | sed -e "s/org.neo4j.server.webserver.port=7474/org.neo4j.server.webserver.port=$lastPort/" | sed -e "s/org.neo4j.server.webserver.https.port=7473/org.neo4j.server.webserver.https.port=$lastSslPort/" > ports/$lastPort/conf/neo4j-server.properties
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j.properties" | sed -e "s/^#remote_shell_port/remote_shell_port/" | sed -e "s/remote_shell_port=1337/remote_shell_port=$lastShellPort/" > ports/$lastPort/conf/neo4j.properties
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j.properties" | sed -e "s/^#remote_shell_port/remote_shell_port/" | sed -e "s/remote_shell_port=1337/remote_shell_port=$lastShellPort/" | sed -e "s/online_backup_enabled=true/online_backup_enabled=false/" > ports/$lastPort/conf/neo4j.properties

        if [ ! -z "$dbName" ]; then
            echo -n "$dbName" > ports/$lastPort/db-name
            echo -n "$neo4jType" > ports/$lastPort/db-type
            echo -n "$currentVersion" > ports/$lastPort/db-version
            echo -n "$lastShellPort" > ports/$lastPort/shell-port
        fi
    fi
}

function renameDatabase {
    if [ -d "ports/$2" ]; then
        if databaseExists "$3"; then
            message "database already exists" "E" $red;
            exit 1;
        else
            echo -n "$3" > "ports/$2/db-name";
            message "database name renamed" "M" $blue;
        fi
    else
        message "port was not given" "E" $red;
    fi
}

function getPlugins {
    plugins="";
    if hash curl; then
        curl -vs http://www.diracian.com/neo4j-plugins/$currentVersion 2> /dev/null 1> plugins;
    elif hash wget; then
        wget -qO-http://www.diracian.com/neo4j-plugins/$currentVersion 2> /dev/null 1> plugins;
    fi
    cat plugins
}

function plugin {
    if [ ! -z "$3" ] && [ "$2" == "list" ] && [ -d "ports/$3" ]; then
        for i in `ls "ports/$3/plugins/" | grep '\.jar$'`; do
            OLDIFS=$IFS;
            IFS=$'\n';
            for line in `cat plugins | grep "$i" `; do
                alias=$(echo $line | cut -d"|" -f1);
                name=$(echo $line | cut -d"|" -f2);
                pad=$(printf "%-6s" "$alias");

                message "    ${blue}[${nocolor}${green}$pad${nocolor}${blue}]${nocolor} - ${cyan}$name${nocolor}";
            done
            IFS=$OLDIFS;
        done
    elif [ "$2" == "list" ]; then
        message "neo4j plugins you can install:" "M" $blue;

        plugins=$(getPlugins);
        OLDIFS=$IFS;
        IFS=$'\n';
        for line in $plugins; do
            alias=$(echo $line | cut -d"|" -f1);
            name=$(echo $line | cut -d"|" -f2);
            pad=$(printf "%-6s" "$alias");

            message "    ${blue}[${nocolor}${green}$pad${nocolor}${blue}]${nocolor} - ${cyan}$name${nocolor}";
        done
        IFS=$OLDIFS;
    elif [ "$2" == "install" ] && [ -d "ports/$4" ]; then
        for i in `cat plugins | grep "$3" | cut -d"|" -f3`; do
            url=$(echo $i | cut -d"|" -f3);
            filename=${url##*/};
            if [ -f "ports/$4/plugins/$filename" ]; then
                message "plugin is already installed." "E" $red;
            else
                if hash curl; then
                    curl -# -L "$url" -o "ports/$4/plugins/$filename";
                elif hash wget; then
                    wget "$url" -O "ports/$4/plugins/$filename";
                fi
            fi
        done
    elif [ "$2" == "remove" ] && [ -d "ports/$4" ]; then
        for i in `cat plugins | grep "$3" | cut -d"|" -f3`; do
            url=$(echo $i | cut -d"|" -f3);
            filename=${url##*/};
            if [ -f "ports/$4/plugins/$filename" ]; then
                rm "ports/$4/plugins/$filename";
                message "plugin [$3 -- $filename] was removed." "M" $blue;
            else
                message "plugin is not installed." "E" $red;
            fi
        done
    elif [ ! -d "ports/$4" ]; then
        message "port [$4] does not exists." "E" $red;
    fi
}

function displayList {
    if [ "$2" == "plugins" ]; then
        message "neo4j plugins you can install:" "M" $blue;

        if hash curl; then
            downloader_string="curl -vs";
        elif hash wget; then
            downloader_string="wget -qO-";
        fi
        plugins=$($downloader_string http://internal.www.diracian.com/neo4j-plugins/$currentVersion);

        OLDIFS=$IFS;
        IFS=$'\n';
        for line in $plugins; do
            alias=$(echo $line | cut -d"|" -f1);
            name=$(echo $line | cut -d"|" -f2);
            pad=$(printf "%-6s" "$alias");

            message "${blue}[${nocolor}${green}$pad${nocolor}${blue}]${nocolor} - ${cyan}$name${nocolor}";
        done
        IFS=$OLDIFS;

    else
        message "neo4j databases:" "M" $blue;
        for x in $(ls ports); do
            dbAddon="";
            if (portIsTaken "$x"); then
                status="${green}on ${nocolor}";
            else
                status="${blue}off${nocolor}";
            fi
            if [ -f "ports/$x/db-name" ]; then
                dbName=$(cat "ports/$x/db-name");
                type=$(cat "ports/$x/db-type");
                version=$(cat "ports/$x/db-version");
                typeInfo=$(printf "%10s" "$type");
            #    dbAddon="- <${grey}$typeInfo${nocolor}:${yellow}$version${nocolor}> - db [${magenta}$dbName${nocolor}]";
                dbAddon="- <${grey}$typeInfo${nocolor}:${yellow}$version${nocolor}> - [${magenta}$dbName${nocolor}]";
            fi
            # message "    $x - status [$status] $dbAddon";
            message "    $x - [$status] $dbAddon";
        done
    fi
}

function destroyDatabase {
    if [ ! -z "$2" ] && [ -d "ports/$2" ]; then
        if (portIsTaken "$2"); then
            ./ports/"$2"/bin/neo4j stop;
        fi
        rm -r "ports/$2";
        message "database on port [$2] was deleted" "M" $blue;
    else
        if [ ! -d "ports/$2" ]; then
            message "port [$2] does not exist" "W" $red;
        else
            message "was unable to delete port [$2]" "W" $red;
        fi
    fi
}

function check {
    if [ "$1" == "start" ] && (portIsTaken "$2"); then
        message "database already started" "W" $red;
        return 1;
    elif [ "$1" == "stop" ] && (! portIsTaken "$2") && [ -d "ports/$2" ]; then
        message "database was already stopped" "W" $red;
        return 1;
    elif [ ! -d "ports/$2" ]; then
        message "database was never created for that port" "W" $red;
        return 1;
    fi
    return 0;
}

function databaseCommand {
    if (check "${@}"); then
        cd "ports/$2/bin";
        ./neo4j "$1";
    fi
}

function startDatabase {
    databaseCommand "${@}" | grep http;
}

function stopDatabase {
    databaseCommand "${@}";
}

function databaseStatus {
    databaseCommand "${@}";
}

function startShell {
    shellPort=$(cat ./ports/"$2"/shell-port);
    if (portIsTaken "$2"); then
        ./ports/"$2"/bin/neo4j-shell -port "$shellPort";
    else
        message "database has not been started" "W" $red;
    fi
}

blue="\033[0;34m";
green="\033[0;32m";
red="\033[0;31m";
grey="\033[0;37m";
magenta="\033[0;35m";
cyan="\033[0;36m";
yellow="\033[33m";
nocolor="\033[0m";

username=$(whoami);
startPort=7474;
startShellPort=1337;
currentVersion="2.3.1";
neo4jType="community";

setup;

case "$1" in
    create)
        createDatabase "${@}";
        ;;
    rename-db)
        renameDatabase "${@}";
        ;;
    start)
        startDatabase "${@}";
        ;;
    stop)
        stopDatabase "${@}";
        ;;
    destroy)
        destroyDatabase "${@}";
        ;;
    shell)
        startShell "${@}";
        ;;
    list)
        displayList "${@}";
        ;;
     plugin)
        plugin "${@}";
        ;;
    *)
        usage;
        ;;
esac
