#!/bin/bash

PROGNAME=$(basename $0)

OUTFILE="/tmp/ftplist.$RANDOM.txt"
CMDFILE="/tmp/ftpcmd.$RANDOM.txt"
ndays=14

print_usage() {
    echo ""
    echo "$PROGNAME - Delete files older than N days from an FTP server"
    echo ""
    echo "Usage: $PROGNAME -s -u -p -f (-d)"
    echo ""
    echo "  -s  FTP Server name"
    echo "  -u  User Name"
    echo "  -p  Password"
    echo "  -f  Folder"
    echo "  -d  Number of Days (Default: $ndays)"
    echo "  -h  Show this page"
    echo ""
    echo "Usage: $PROGNAME -h"
    echo ""
    exit
}

# Parse parameters
options=':hs:u:p:f:d:'
while getopts $options flag
do
    case $flag in
        s)
            FTPSITE=$OPTARG
            ;;
        u)
            FTPUSER=$OPTARG
            ;;
        p)
            FTPPASS=$OPTARG
            ;;
        f)
            FTPDIR=$OPTARG
            ;;
        d)
            ndays=$OPTARG
            ;;
        h)
            print_usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done 

shift $(($OPTIND - 1))

if [[ -z "$FTPSITE" || -z "$FTPUSER" || -z "$FTPPASS" || -z "$FTPDIR" ]];
then
    echo "ERROR: Missing parameters"
    print_usage
fi


# work out our cutoff date
TDATE=`date --date="$ndays days ago" +%Y%m%d`

echo FTP Site: $FTPSITE
echo FTP User: $FTPUSER
echo FTP Password: $FTPPASS
echo FTP Folder: $FTPDIR
echo Removing files older than $TDATE

# get directory listing from remote source
ftp -i -n $FTPSITE <<EOMYF > /dev/null
user $FTPUSER $FTPPASS
binary
cd $FTPDIR
ls -l $OUTFILE
quit
EOMYF

if [ -f "$OUTFILE" ]
then

    # Load the listing file into an array
    lista=($(<$OUTFILE))

    # Create the FTP command file to delete the files
    echo "user $FTPUSER $FTPPASS" > $CMDFILE
    echo "binary" >> $CMDFILE
    echo "cd $FTPDIR"  >> $CMDFILE

    COUNT=0

    # loop over our files
    for ((FNO=0; FNO<${#lista[@]}; FNO+=9));do
        # month (element 5), day (element 6) and filename (element 8)
        FMM=${lista[`expr $FNO+5`]}
        FDD=${lista[`expr $FNO+6`]}
        FYY=${lista[`expr $FNO+7`]}

        if [[ $FYY == *\:* ]]
        then
            FDATE=`date -d "$FMM $FDD" +'%Y%m%d'`
        else
            FDATE=`date -d "$FMM $FDD $FYY" +'%Y%m%d'`
        fi

        # echo $FDATE
        # check the date stamp
        if [[ $FDATE -lt $TDATE ]];
        then
            echo "Deleting ${lista[`expr $FNO+8`]}"
            echo "delete ${lista[`expr $FNO+8`]}" >> $CMDFILE
            COUNT=$[$COUNT + 1]
        fi
    done
    echo "quit" >> $CMDFILE


    if [[ $COUNT -gt 0 ]];
    then
        cat $CMDFILE | tr -d "\r" > $CMDFILE
        ftp -i -n $FTPSITE < $CMDFILE > /dev/null
    else
        echo "Nothing to delete"
    fi

    rm -f $OUTFILE $CMDFILE
fi
