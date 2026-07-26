@echo off
copy labels2200_common.txt /b + labels2200b.txt /b labels_temp.txt
copy comments2200_common.txt /b + comments2200b.txt /b comments_temp.txt
perl wdis.pl wang2200b.rom labels_temp.txt comments_temp.txt >listing2200b.txt 2>listing2200b.err
del labels_temp.txt comments_temp.txt