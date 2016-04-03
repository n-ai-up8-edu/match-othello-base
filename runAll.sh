#!/bin/bash

tab0=( Godzilla-MC-1k-1 Godzilla-MC-1k-2 Godzilla-MC-1k-3 Godzilla-MC-1k-4 Godzilla-MC-1k-5 Godzilla-MC-1k-6 Godzilla-MC-1k-7 Godzilla-MC-1k-8 Godzilla-MC-1k-9 )

tab1=( Zilla0.1 Zilla0.2 Zilla0.3 Zilla0.4 Zilla0.5 Zilla0.6 Zilla0.7 Zilla0.8 Zilla0.9 )

for ((i=0; i < ${#tab0[@]}; i++)); do 
    echo "RUNNING ./run2.sh ./${tab0[$i]} ./${tab1[$i]} 1"; 
    ./run2.sh ./${tab0[$i]} ./${tab1[$i]} 1; 
    mkdir "${tab0[$i]}--${tab1[$i]}--1";
    cp *sgf ${tab0[$i]}--${tab1[$i]}--1;
    mv data ${tab0[$i]}--${tab1[$i]}--1;
    mv log1 ${tab0[$i]}--${tab1[$i]}--1;
done

for ((i=0; i < ${#tab0[@]}; i++)); do 
    mv ${tab0[$i]}--${tab1[$i]}--1/data .;
    echo "/// --- /// --- ///";
    pike ./data2score.pike;
    mv data ${tab0[$i]}--${tab1[$i]}--1;
done
 
