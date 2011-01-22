#!/bin/sh

GIT_SRV=git
GIT_PATH=/srv/git
SKEL_URL=ssh://$GIT_SRV$GIT_PATH/example-c-project.git

[ -z "$TMPDIR" ] && TMPDIR=/tmp

function usage() {
    echo "Usage: `basename $0` <project name>"
    echo "  Initialize a new c/c++ project"
}

function create_git_repo() {
    name=$1 
    repo_path=$GIT_PATH/$name.git
    ssh $GIT_SRV "if [ ! -e $repo_path ]; then mkdir $repo_path && cd $repo_path && git init --bare --shared; else echo $repo_path already exists on server $GIT_SRV; exit 1; fi"
    [ $? -ne 0 ] && {
        echo "Aborted."
        exit 1
    }

    (pushd $TMPDIR && git clone ssh://$GIT_SRV/$repo_path &&
    pushd $name && touch .gitignore &&
    git add .gitignore && git commit -m 'added .gitignore' && git push origin master &&
    popd && rm -rf $name) || {
        echo "Failed to set up repository $name"
        exit 1
    }

    git submodule add ssh://$GIT_SRV/$repo_path || {
        echo "Failed to set up submodule for $name"
        exit 1
    }
}

function create_project_skel() {
    git archive --remote $SKEL_URL master | tar xf -
}

project_name=$1
[ -z "$project_name" ] && {
    usage
    exit 1
}

[ -e $project_name ] && {
    echo "Error: something named $project_name already exists in `pwd`"
    ls -ld $project_name
    exit 1
}

echo ""
echo "Create new project named $project_name? (y/n)"
while read ans; do
    case $ans in
        y*) break;;
        n*) echo "Aborted"; exit 1;;
        *) echo "Please anwser y or n";;
    esac
done

create_git_repo $project_name
(pushd $project_name && create_project_skel $project_name && ls -l)
git add $project_name
git status

echo "Completed."
