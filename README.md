Hi,
this is my simple WANG2200 disassembler, written in perl.
I used it to create a listing to better understand the WANG 2200 firmware.

The perl code is not the best, but works for me. :-)

usage: wdis binarysource labelfile commentfile [asm]

You'll find an example in the batch files here.

The disassembler accepts/needs a label file and a comment file.
In the label file you may define names for some firmware addresses.
In the comment file you may define comments, which will appear in the appropriate line.
The "asm" keyword is optional and is used to suppress the address and opcode portions, only the pure mnemonics and comments are printed.

The output must be redirected to a target file and the error output may be redirected to an error log.

I maintain two sorts of label and comment files.
One is for entries that appear in all versions of the 2200 code, the other contains entries which are related to a specific version, eg. 2200B, 2200T, ...
In the batch files, I simply merge the common and the version specific files and pass it to the wdis program.
That's bad style, I know. Since this is mainly a private project, it's OK for me :-)

My initial intention was to find senseful names of subroutines etc.
The more names I found, the better was the understanding of the firmware code. Adding comments of course was also helpful.
After many iterations of naming, commenting and rerunning the disassembler, I now have a more or less complete listing.
It helped me to understand e.g. the cassette drive code and much more.

My last versions of label and comment files are also included here.

Have fun.
