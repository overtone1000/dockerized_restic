#!/bin/bash

echo
echo "Initializing path"
PATH="/usr/local/bin:/usr/bin:/bin"

echo
echo "Restic version"
restic version
echo

if [ -z $RESTIC_PASSWORD ] #-z checks if it is unset
then
    echo "Restic password not set."
    exit 1
fi

if [ -z $REPO_LOCATION ] #-z checks if it is unset
then
    echo "Repo not set."
    exit 1
else
    echo "Repo: $REPO_LOCATION"
fi

if [ -z $DATA_LOCATION ] #-z checks if it is unset
then
    echo "Data location not set."
    exit 1
else
    echo "Data: $DATA_LOCATION"
fi

health() {
    if [ -z $BACKUP_HEALTH_URL ] #-z checks if BACKUP_HEALTH_URL is unset
    then
        echo "Health URL is not set. Environment variable is $BACKUP_HEALTH_URL"
    else
        wget -nv "$1" -T 10 -t 5 -O /dev/null
    fi
}

init() {
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD" init
    return $?
}

check() {
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD" check
    return $?
}

unlock() {
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD" unlock --remove-all
    return $?
}

snapshots() {
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD" snapshots
    return $?
}

backup() {
    #Set host to allow finding the correct parent snapshot even after the container name changes
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD" --host "containerized_restic" backup $DATA_LOCATION
    return $?
}

forget_prune() {
    #Decided to omit host flag here. If any errant snapshots are around, they'll eventually get cleaned up better this way.
    restic --repo $REPO_LOCATION --password-command "echo $RESTIC_PASSWORD"  forget --prune $PRUNE_CONFIG
    return $?
}

backup_forget_prune_health() {
    health $BACKUP_HEALTH_URL/start
    if backup
    then
        if forget_prune
        then
            health $BACKUP_HEALTH_URL
        else
            health $BACKUP_HEALTH_URL/fail/$RESULT
        fi
    else
        health $BACKUP_HEALTH_URL/fail/$RESULT
    fi
}

unlock_then_check() {
if unlock
then
    if check
    then
        echo "Unlock and check succeeded."
    else
        return 1
    fi
else
    echo "Couldn't unlock."
    return 1
fi
}

#Init repo
if init
then
    echo "Repository initialized."
else
    echo "Repository already exists."
fi

#Check repo
if check
then
    echo "Repository check ok."
else
    echo "Repository check failed."
    if unlock_then_check
    then
        echo "Check retry successful"
    else
        exit 1
    fi  
fi

#Snapshots
snapshots

if [ "$EXECUTION_MODE" = "bindable" ]
then
    while true; do sleep 86400; done
elif [ "$EXECUTION_MODE" = "oneshot" ]
then
    if backup_forget_prune_health
    then
        echo "Successful backup."
    else
        echo "Backup failed. Attempting unlock and check."
        if unlock_then_check
        then
            echo "Retrying backup."
            backup_forget_prune_health
        fi            
    fi
elif [ "$EXECUTION_MODE" = "looping" ]
then
    #Unlock and check on first loop pass.
    UNLOCK_AND_CHECK=true

    echo
    echo "Entering infinite loop"
    while true
    do
        if [ $UNLOCK_AND_CHECK = true ]
        then
            echo "Unlocking and checking repo."
            if unlock
                then
                check
            fi
            UNLOCK_AND_CHECK=false
        fi

        if backup_forget_prune_health
        then
            echo "Successful backup."
        else
            #If backup fails, try an unlock and check on the next pass.
            UNLOCK_AND_CHECK=true
        fi

        echo "Sleeping."
        sleep 15m
    done
else
    echo
    echo "EXECUTION_MODE must be equal to bindable, oneshot, or looping"
    exit 1
fi