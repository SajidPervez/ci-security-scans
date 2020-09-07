#!/bin/bash
#set -x
# Exit on error
set -e

# Functions
python_tool_install() {
    # Install python3
    sudo apt-get install software-properties-common
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt-get update
    sudo apt-get install python3.6
    python3 --version
    # Install curl
    sudo apt-get update
    sudo apt-get install curl
    sudo apt install python3-pip
    pip install wheel
    pip --version
    export PATH="$PATH:~/.local/bin"
}

dotnet_tool_install() {
    # Register Microsoft key and feed
    wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    # Install .NET SDK
    sudo apt-get update
    sudo add-apt-repository universe
    sudo apt-get install -y apt-transport-https
    sudo apt-get install dotnet-sdk-3.0
}

node_install() {
    sudo apt-get install curl
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install nodejs && node -v && npm -v
}


# Show Usage
usage() {
cat << EOF  
Usage: ./ci-security.sh <path-to-project-dir> -s [path-to-sln-file] 
1. For .NET project
    ./ci-security.sh <path-to-project-dir> -s <path-to-sln-file>
    e.g.
    ./ci-security.sh /src -s /src/project.sln

2. For NPM project and Python project
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
while getopts "s:" arg; do
    case "${arg}" in
        s)
            SLN=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
DIR=${1?$( usage )}
echo "DIR = ${DIR}"

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
        echo "Path to sln file is empty"
        exit 1
    fi
else
    # Check project type: NPM and python
    if [[ -n $(find $DIR -maxdepth 1 -type f -name "*.py") ]]; then
        echo "Python project"
        TYPE="Python"
    elif [[ -n $(find $DIR -maxdepth 1 -type f -name "package.json" -o -name "yarn.lock") ]]; then
        echo "NodeJS project"
        TYPE="Node"
    fi
fi

case $TYPE in
    ".NET")
        echo "Hello .NET!" ;
        dotnet_tool_install ;
        dotnet --info
        dotnet tool install --tool-path . CycloneDX ;
        #./dotnet-CycloneDX --help
        #./dotnet-CycloneDX $SLN -o $DIR
        ./dotnet-CycloneDX $SLN -o $DIR
        cat $DIR/bom.xml
        ;;

    "Python")
        echo "Hello python!" ;
        python_tool_install ;
        pip freeze > requirements.txt
        # Install cyclonedx to create sbom
        pip install cyclonedx-bom ;
        #3. Run it and it will generate sbom in current directory
        pip show cyclonedx-bom ;
        echo $PATH ;
        #cyclonedx-py -i $DIR/requirements.txt -o $DIR ;
        cyclonedx-py
        ls -ltr $DIR
        #ls -ltr /home/vsts/.local/lib/python2.7/site-packages/
        #ls -ltr ~/.local/bin
        cat $DIR/bom.xml
        ;;

    "Node")
        echo "Hello node! Let me setup the env..";
        node_install ;
        sudo npm install -g @cyclonedx/bom ;
        cd $DIR
        npm install ;
        ls -ltr ;
        cyclonedx-bom -o bom.xml ;
        ls -ltr
        cd security-scans
        #cat bom.xml
     ;;

    *)
        echo ":(" ;
        echo "Project type not supported. Only .NET, NodeJS and Python are supported." ;
        exit 1
esac
#exit 0

# Dep-Track URL
DT_URL="https://deptrack.australiasoutheast.cloudapp.azure.com/api/v1"
# Read project UUID from env
DEFAULT_UUID="2d395a41-d684-45c7-a8f9-92d602a43223"
DEFAULT_KEY=""
PROJECT_UUID=${PROJECT_UUID:-$DEFAULT_UUID}

API_KEY=${API_KEY:-$DEFAULT_KEY}
# Generate base64 encoded bom without any whitespaces
#b64bom=$(base64 -w 0 $DIR/bom.xml)
mv $DIR/bom.xml .

#cat bom.xml 
#echo $b64bom
#5. Post sbom to depenedency track
cat > payload.json <<__HERE__
{
  "project": "${PROJECT_UUID}",
  "bom": "$(cat bom.xml |base64 -w 0 -)"
}
__HERE__
# Working
# RES="$(curl -X "PUT" "http://104.43.15.124:443/api/v1/bom" \
#         -H "Content-Type: application/json" \
#         -H "X-API-Key: ${API_KEY}" \
#         -d @payload.json)"

# New
RES="$(curl -k -X "PUT" "${DT_URL}/bom" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: ${API_KEY}" \
        -d @payload.json)"

# RES="$(curl -X "PUT" "http://104.43.15.124:443/api/v1/bom" \
#          -H 'Content-Type: application/json' \
#          -H "X-API-Key: ${API_KEY}" \
#          -d '{
#                 "project": "'${PROJECT_UUID}'",
#                 "bom": "'${b64bom}'"
#             }')"
#echo $RES
TOKEN=$(echo $RES | jq -r '.token')

# Pool DT and pull results when ready
if [[ -z $TOKEN ]]; then
    echo "BOM upload failed. Check error: ${RES}"
else 
    while :
    do
        echo "Dependency Track is scaning,please wait.."
        # Working
        # RESULTS="$(curl -X "GET" "http://104.43.15.124:443/api/v1/bom/token/${TOKEN}" \
        #             -H 'Content-Type: application/json' \
        #             -H "X-API-Key: ${API_KEY}")"
        # New
        RESULTS="$(curl -k -X "GET" "${DT_URL}/bom/token/${TOKEN}" \
                    -H 'Content-Type: application/json' \
                    -H "X-API-Key: ${API_KEY}")"
        processing=$(echo $RESULTS | jq -r '.processing')
        if [[ $processing = false ]]; then
            echo "Scanning..Done!"
            # Working
            # FINDINGS="$(curl -X "GET" "http://104.43.15.124:443/api/v1/finding/project/${PROJECT_UUID}" \
            #         -H 'Content-Type: application/json' \
            #         -H "X-API-Key: ${API_KEY}")"
            # New
            FINDINGS="$(curl -k -X "GET" "${DT_URL}/finding/project/${PROJECT_UUID}" \
                    -H 'Content-Type: application/json' \
                    -H "X-API-Key: ${API_KEY}")"
            break
        else
            continue
        fi
    done 
fi

# Search through findings and report results here

#echo $FINDINGS
#echo $FINDINGS |jq -r '.[].vulnerability.severity'
c=0; h=0; m=0; l=0; u=0;
for severity in $(echo $FINDINGS |jq -r '.[].vulnerability.severity')
do
    case $severity in
        "CRITICAL")
            c=$((c+1))
        ;;
        "HIGH")
            h=$((h+1)) 
        ;;
        "MEDIUM")
            m=$((m+1))
        ;;
        "LOW")
            l=$((l+1))
        ;;
        "UNASSIGNED")
            u=$((u+1))
    esac
done

# Output results
echo "Number of vulnerabilities:"
echo "Critical: $c"
echo "High: $h"
echo "Medium: $m"
echo "Low: $l"
echo "Unassigned: $u"

