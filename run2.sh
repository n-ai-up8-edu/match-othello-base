#!/bin/bash

if [ $# -ne 3 ]; then
    echo "////////////////////////////////////////////////////////////";
    echo "// to play NB_GAMES*2 matchs between 2 programs P0 and P1 //";
    echo "// $0 ./P0 ./P1 NB_GAMES ////////////////////////////";
    echo "////////////////////////////////////////////////////////////";
    exit 0;
fi

PRG1=$1
PRG2=$2
NB_GAMES=$3

rm -f *sgf
rm -f data/scores.txt
if [ ! -d data ]; then
    mkdir data;
fi

pike othello_gtp.pike -f $PRG1 -s $PRG2 -n $NB_GAMES -l 1 -v 1 2>log1 
pike othello_gtp.pike -f $PRG2 -s $PRG1 -n $NB_GAMES -l 1 -v 1 2>log2

