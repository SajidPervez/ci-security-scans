#!/bin/bash
#set -x
# Show Usage
usage() {
cat << EOF  
Usage: ./ci-security.sh <path-to-project-dir> -s [path-to-sln-file] 
1. For .NET project
    ./ci-security.sh  -s <path-to-sln-file> <path-to-project-dir>
    e.g.
    ./ci-security.sh -s /src/project.sln /src

2. For Node project
    ./ci-security.sh -n <npm version> -y <yarn version> <path-to-project-dir>
    e.g.
    ./ci-security.sh -n 10.15.1 -y 1.20.1 /src

3. Python project
    ./ci-security.sh <path-to-project-dir>
    e.g.
    ./ci-security.sh /src

Options:
-h      Display help

-s      Path to *.sln/*.csproj/project (required only for .NET project). 

EOF
}


# Set SLN to null
SLN=Null
NPM_VER=
YARN_VER=
while getopts "s:n:y:" arg; do
    case ${arg} in
        s)
            SLN=${OPTARG}
            echo $OPTIND
            ;;
        n)
            NPM_VER=${OPTARG}
            echo $OPTIND
            ;;
        y)
            YARN_VER=${OPTARG}
            echo $OPTIND
            ;;
        :)
           echo "Error: -${OPTARG} requires an argument."
           exit 1
            ;; 
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))
DIR=${1?$( usage )}
if [ -z "${DIR}" ]; then
    usage
    exit 1
fi

if [[ "$SLN" != "Null"  ]]; then
    # Validition for .NET projects
    if [[ ! -z "${SLN}" ]]; then
        echo "Path to SLN file = ${SLN}"
        # It looks like a .net project, check file type
        #filename=$(echo "${SLN##*/}")
        filename=$(basename "$SLN" | sed -r 's|^(.*?)\.\w+$|\1|')
        echo "filename = ${filename}"
        #ext=$(echo "${SLN##*.}")
        ext=$(echo "$SLN" | sed 's/^.*\.//')
        echo "ext = ${ext}"
        if [[ -z $filename || -z $ext ]]; then
            echo "Missing filename or extension, please check .NET project path to sln file."
            exit 1
        fi
        # Check if file exists
        if [[ -n $(find $DIR -type f -name "${filename}.${ext}") ]]; then
            # file exists, lets verify type
            if [[ $ext == "sln" || $ext == "csproj" || $ext == "vbproj" ]]; then
                echo ".NET project"
                TYPE=".NET"
            elif [[ $filename == "projects.config" ]]; then
                echo ".NET project"
                TYPE=".NET"
            else
                echo "Missing filename, .NET project supported filetypes are *.sln, *.csproj, *.vbproj & projects.config"
                exit 1
            fi
        else
            echo "Could not find ${filename}.${ext}, please check filename is correct."
            exit 1
        fi
    else
        echo "Path to sln file is not set."
        exit 1
    fi
else
    # Check project type: NPM and python
    if [[ -n $(find $DIR -maxdepth 1 -type f -name "*.py") ]]; then
        echo "Python project"
        TYPE="Python"
    elif [[ -n $(find $DIR -maxdepth 1 -type f -name "yarn.lock") ]]; then
        if [[ -z $YARN_VER ]]; then
            echo "Missing yarn version."
            exit 1
        fi
        # Yarn version has a format v1.2.3
        if [ ${YARN_VER:0:1} == "v" ]; then
            # remove 'v' from version
            YARN_VER=${YARN_VER:1}
            echo $YARN_VER
        fi
        echo "NodeJS yarn project"
        echo "yarn version to use: ${YARN_VER}"
        TYPE="yarn"
    elif [[ -n $(find $DIR -maxdepth 1 -type f -name "package.json") && ! -n $(find $DIR -maxdepth 1 -type f -name "yarn.lock") ]]; then
        if [[ -z $NPM_VER ]]; then
            echo "Missing npm version."
            exit 1
        fi
        if [ ${NPM_VER:0:1} == "v" ]; then
            # remove 'v' from version
            NPM_VER=${NPM_VER:1}
            echo $NPM_VER
        fi
        echo "NodeJS npm project"
        echo "npm version to use: ${NPM_VER}"
        TYPE="npm"
    fi
fi
