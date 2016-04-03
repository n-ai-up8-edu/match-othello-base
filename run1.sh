#!/bin/bash
if [ $# -ne 4 ]; then
    echo "$0 PLAYER1 PLAYER2 OUTPUTDIR NB_GAMES";
    exit 0;
fi

PRG1=$1
PRG2=$2
OUTPUTDIR=$3
NB_GAMES=$4

if [ ! -d $OUTPUTDIR ]; then
    mkdir $OUTPUTDIR;
fi

pike run_many_games.pike -f $PRG1 -s$PRG2 -o $OUTPUTDIR -n $NB_GAMES -v 1
pike run_many_games.pike -f $PRG2 -s$PRG1 -o $OUTPUTDIR -n $NB_GAMES -v 1

