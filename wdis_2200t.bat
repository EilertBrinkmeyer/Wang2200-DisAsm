@echo off
copy labels2200_common.txt /b + labels2200t.txt /b labels_temp.txt
copy comments2200_common.txt /b + comments2200t.txt /b comments_temp.txt
perl wdis.pl wang2200t.rom labels_temp.txt comments_temp.txt >listing2200t.txt 2>listing2200t.err
del labels_temp.txt comments_temp.txt