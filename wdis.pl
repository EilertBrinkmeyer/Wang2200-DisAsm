# arg0 is binary source file *.ROM
# arg1 is label file  *.txt
# arg2 is comment file *.txt
# arg3 is ASM flag

#use strict;
use Getopt::Std;
# these switches are recognized:
# -a : makes ASM compatible output (otherwise more readable)
# -o : sets the ROM address to this value (default 0)
getopts('ao:');
  
# file names
#my $filename = "WANG2200B.ROM";
#my $labelfile = "labels2200b.txt";
#my $commentfile = "comments2200b.txt";
my $filename = @ARGV[0];
my $labelfile = @ARGV[1];
my $commentfile = @ARGV[2];

my $hexic;
my $orgadr;
my $asm;
 
my $data; # read buffer
my $nbytes;

if (@ARGV < 3) {
	die "usage: wdis binarysource labelfile commentfile [asm]\n";
}

# ASM mode omits address and objectcode, output just contains mnemonics (for use in assembler)
if ($opt_a) {
	$asm = "ASM";
};


if ($opt_o) {
	if (lc(substr($opt_o,0,2) eq "0x")) {
		$orgadr = hex($opt_o);
	}
	else {
		$orgadr = $opt_o;
	}
}
else {
	$orgadr = 0;
}
print STDERR "option orgadr = $orgadr\n";
print STDERR "option asm = $asm\n";

# initialize instruction counter:
$ic = $orgadr;

my $uode;
my $bits;
my $separator_line;
my @regop     = ("OR","XOR","AND","DSC","A","AC","DA","DAC","ORI","XORI","ANDI","--","AI","ACI","DAI","DACI");
my @branchop  = ("BER","BNR","SB","B ","BT","BF","BEQ","BNE");
my @miniop    = ("CIO","SR","TP","TA","XP","TPI","TIP","TMP","TP+1","TP-1","TP+2","TP-2","XP+1","XP-1","XP+2","XP-2");
my @pcmod     = ("","","","","","","","","",",PC-",",PC+",",PC-","",",PC-",",PC+",",PC+");
my @abussrc   = ("R","R","R","R","R","R","R","R","CH","CH","CH","0","CL","CL","CL","0");
my @bbusx0src = ("R","R","R","R","R","R","R","R","KH","KL","ST1","ST2","PC1","CH","CL","0");
my @bbusx1src = ("R","R","R","R","R","R","R","R","ST3","ST4","PC2","PC3","PC4","CH","CL","0");
my @cbusx0dst = ("R","R","R","R","R","R","R","R","KH","KL","ST1","ST2","PC1","!","!","");
my @cbusx1dst = ("R","R","R","R","R","R","R","R","ST3","ST4","PC2","PC3","PC4","!","!","");
my @memop     = ("",",R",",W1",",W2");

my %labels;
my %comments;
my %local_labels;

sub r {
	my ($str,$pos,$len) = @_;
	return substr ($str,19-$pos,$len);
}

sub abus {
	my ($src, $x) = @_;
	if ($src < 8) {
		return sprintf("F%d",$src)
	}
	else {
		return sprintf("%s",@abussrc[$src]); 
	}
}

sub bbus {
	my ($src, $x) = @_;
	if ($src < 8) {
		return sprintf("F%d",$src)
	}
	elsif ($x == '0') {
		return sprintf("%s",@bbusx0src[$src]); 
	}
	else {
		return sprintf("%s",@bbusx1src[$src]); 
	}
}

sub cbus {
	my ($src, $x) = @_;
	if ($src < 8) {
		return sprintf("F%d",$src)
	}
	elsif ($x == '0') {
		return sprintf("%s",@cbusx0dst[$src]); 
	}
	else {
		return sprintf("%s",@cbusx1dst[$src]); 
	}
}
sub disass {
	my ($bits, $ic) = @_;
	my @r;
	my $mne;
	my $opcode,$reg, $branchic, $hexic, $label;
	my $xbit, $bbussrc, $memory, $abussrc, $cbusdst, $imm;
	my $ic1adr, $ic2adr, $ic3adr, $ic4adr, $mask;
	
	@r = split (//, reverse $bits);
	$b = reverse $bits;
	$separator_line = 0;
	
	if (r($bits,19,5) ==  '01011') {
		# mini instructions
		$opcode = oct('0b'.r($bits,14,5));
		$memory  = oct('0b'.r($bits,9,2));
		$abussrc = oct('0b'.r($bits,7,4));		
		$reg     = oct('0b'.r($bits,3,4));
		my $memop = @memop[$memory];
		my $pcmod = @pcmod[$abussrc];
		my $ciomode = "";
		if ( $memop eq "" && $pcmod ne "") {
			$memop = ','; # insert comma for empty field
		}
		if ($opcode == 0) { #CIO instruction
			$ciomode .= " LDAB" if (@r[7] == '1');
			$ciomode .= " ABS" if (@r[6] == '1');
			$ciomode .= " OBS" if (@r[5] == '1');
			$ciomode .= " CBS" if (@r[4] == '1');
			$ciomode =~ s/^\s+//; # LTRIM
			$ciomode =~ s/ /,/g; # replace spaces by comma
			$mne = sprintf("%-11s%s",@miniop[$opcode] . @memop[$memory], $ciomode); #r($bits,7,8)
		}
		elsif ($opcode ~~ [1,5,6,7] ) {
			if ($memory >= 2) {
				$mne = sprintf("%-11s%s",@miniop[$opcode] . $memop . @pcmod[$abussrc],abus($abussrc,0));
			}
			else {
				$mne = sprintf("%-11s",@miniop[$opcode] . @memop[$memory]);
			}
		}
		else {
			if ($memory >= 2) {
				$mne = sprintf("%-11sAUX%d,%s",@miniop[$opcode] . $memop . @pcmod[$abussrc],$reg,abus($abussrc,0));
			}
			else {
				$mne = sprintf("%-11sAUX%d",@miniop[$opcode] . @memop[$memory],$reg);
			}
		}
		if (@miniop[$opcode] eq "SR") {
			$separator_line=1;
		}
		elsif (@miniop[$opcode] eq "TPI") {
			$separator_line=1;
		}		
	} 
	elsif (@r[19] == '0') {
		# Register Instructions
		$opcode = oct('0b'.r($bits,19,5));
		$xbit = @r[14];
		$bbussrc = oct('0b'.r($bits,13,4));
		$memory  = oct('0b'.r($bits,9,2));
		$abussrc = oct('0b'.r($bits,7,4));
		$cbusdst = oct('0b'.r($bits,3,4));
		$imm     = oct('0b'.r($bits,7,4));
		my $memop = @memop[$memory];
		my $pcmod = @pcmod[$abussrc];
		if ( $memop eq "" && $pcmod ne "") {
			$memop = ','; # insert comma for empty field
		}
		
		if (@r[18] == '0') { # immediate operand
			$mne = sprintf("%-11s%s,%s,%s",@regop[$opcode] . $memop . @pcmod[$abussrc],abus($abussrc,$xbit),bbus($bbussrc,$xbit),cbus($cbusdst,$xbit));
		}
		else {
			$mne = sprintf("%-11s0x%1X,%s,%s",@regop[$opcode] . @memop[$memory],$imm,bbus($bbussrc,$xbit),cbus($cbusdst,$xbit));
		}
	}
	else {
		# Branch instructions
		$opcode = oct('0b'.r($bits,18,3));
		$bbussrc = oct('0b'.r($bits,15,4));
		$abussrc = oct('0b'.r($bits,7,4));	
		$ic1adr = oct('0b'.r($bits,3,4));
		$ic2adr = oct('0b'.r($bits,11,4));
		$ic3adr = oct('0b'.r($bits,7,4));
		$ic4adr = oct('0b'.r($bits,15,4));
		$mask   = oct('0b'.r($bits,7,4));
		$label  = "";
		
		if ($opcode ~~ [2,3] ) {
			$hexic = sprintf("%X%X%X%X",$ic4adr,$ic3adr,$ic2adr,$ic1adr);
			if (exists $labels{$hexic}) {
				if ($asm eq "ASM") {
					$label = $labels{$hexic};
				}
				else {
					$label = $hexic . " (" . $labels{$hexic} . ")";				
				}
			}
			else {
				print STDERR "Missing label for $hexic\n";
				$label = "L" . $hexic;
			}
			$mne = sprintf("%-11s%s",@branchop[$opcode],$label);
		}
		else {
			$branchic = ($ic & 0xff00) | ($ic2adr << 4) | $ic1adr;
			$hexic = sprintf("%04X",$branchic);
			my $hash1 = sprintf("%02X", $branchic >> 8 );
			my $hash2 = sprintf("%02X", $branchic & 0xff);
			
#			if (! $asm) {
#				$label = $hexic;
#			}
			
			if (exists $local_labels{$hash1}{$hash2}) {
				if ($branchic <= $ic) {
					$label .= "<" . $local_labels{$hash1}{$hash2};
				}
				else {
					$label .= ">" . $local_labels{$hash1}{$hash2};
				}
			}
#			elsif ($asm eq "ASM") {
			else {
				$label = "L" . $hexic;	# gen fake label if no local label found (that should NOT happen)
			}
			
			if ($opcode ~~ [0,1] ) {
				$mne = sprintf("%-11s%s,%-4s%s",@branchop[$opcode],abus($abussrc,0),bbus($bbussrc,0),$label);
			}
			else {
				$mne = sprintf("%-11s0x%1X,%-4s%s",@branchop[$opcode],$mask,bbus($bbussrc,0),$label);		
			}
		}
		if (@branchop[$opcode] eq "B ") {
			$separator_line=1;
		}
	}
	return $mne;
}


# Read label definitions
#open SOURCE, @ARGV[0]     or die "Error opening file '@ARGV[0]': $!\n";
open LABELSIN, $labelfile or die "Error opening file $labelfile: $!\n";
while (<LABELSIN>) {
	chomp();
	next if /^\s*#/;  # skip comments
	next if !$_; # skip empty lines
	(my $ic,my $label) = split /:/;
	if ($label) {
		if ($labels{uc($ic)}) {
			print STDERR "WARN: Duplicate address in $labelfile, line $.: $_\n";
		}
		$labels{uc($ic)} = $label;
	}
	else {
		if ($labels{uc($ic)}) {
			print STDERR "INFO: Deleting entry $ic:$labels{uc($ic)}\n";
			delete $labels{uc($ic)};
		}
		else {
			print STDERR "WARN: Could not delete label $ic\n";
		}
	}
   last if eof(LABELSIN);
}
close LABELSIN;


# Read comments
open COMMENTSIN, $commentfile or die "Error opening file $commentfile: $!\n";
while (<COMMENTSIN>) {
	chomp();
	next if /^\s*#/;  # skip comments
	next if !$_; # skip empty lines
	(my $ic,my $comment) = split /:/;
	if ($comment) {
		if ($comments{uc($ic)}) {
			print STDERR "WARN: Duplicate address in $commentfile, line $.: $_\n";
		}
		$comments{uc($ic)} = $comment;
	}
	else {
		if ($comments{uc($ic)}) {
			print STDERR "INFO: Deleting entry $ic:$comments{uc($ic)}\n";
			delete $comments{uc($ic)};
		}
		else {
			print STDERR "WARN: Could not delete comment $ic\n";
		}
	}
   last if eof(COMMENTSIN);
}
close COMMENTSIN;

# Pass1: generate local labels
open DATAIN, $filename     or die "Error opening file $filename: $!\n";
# set stream to binary mode
binmode DATAIN;
my $opcode;
$ic = $orgadr;
my $page;
my $locl_label_num = 0;
while (read DATAIN, $data, 4) {
	$ucode =  oct(sprintf("0x%02X%02X%02X%02X", (vec $data, 3, 8), (vec $data, 2, 8), (vec $data, 1, 8), (vec $data, 0, 8)));
	my $cmd = $ucode >> 16;
	if ($cmd ~~ [8,9,12,13,14,15]) {
		my $hash1 = sprintf("%02X",($ic >> 8));
		my $hash2 = sprintf("%1X%1X",(($ucode & 0xf00) >> 8), ($ucode & 0xf));
		if (!exists $local_labels{$hash1}{$hash2}) {
			$local_labels{$hash1}{$hash2} = "$locl_label_num";
			$locl_label_num++;
		}
	}
	$ic++;
	if (($ic & 0xff) == 0) {$locl_label_num = 0;}
}
close DATAIN     or die "Error closing $filename: $!\n";


# Pass2: generate mnemonics
open DATAIN, $filename     or die "Error opening file $filename: $!\n";
# set stream to binary mode
binmode DATAIN;
$ic = $orgadr;
while ($nbytes = read DATAIN, $data, 256) {
    # Process data read
	for (my $i = 0; $i < $nbytes/4; $i++) {
		$ucode = sprintf("%08x",vec $data,$i,32);
		$ucode = unpack 'H*', reverse pack 'H*', $ucode;
		$bits = unpack 'B*',   pack 'H*', $ucode;
		# print named label
		my $hexic = sprintf("%04X",$ic);
		if (exists $labels{$hexic}) {
			print $labels{$hexic} . ":\n";
		}
		# Print local label
		my $hash1 = sprintf("%02X",($ic >> 8));
		my $hash2 = sprintf("%02X",($ic & 0xff));
		if (exists $local_labels{$hash1}{$hash2}) {
			print "^" . $local_labels{$hash1}{$hash2} . ":\n";
		}
		
		my $disass_str = disass(substr ($bits,12,20),$ic);
		
		if ($asm eq "ASM") {
			# ASM Mode: just print the mnemonics
			if (exists $comments{$hexic}) {
				printf("\t%-30s\t# %s\n", $disass_str, $comments{$hexic});
			}
			else {
				printf("\t%s\n", $disass_str);
			}
		}
		else {
			if (exists $comments{$hexic}) {
				printf("%04x: %#05s | %-30s\t# %s\n", $ic, substr ($ucode,3,5), $disass_str, $comments{$hexic});
			}
			else {
				printf("%04x: %#05s | %s\n", $ic, substr ($ucode,3,5), $disass_str);
			}
			if ($separator_line eq 1) {
				printf("\n");
			}
		}
		$ic++;
		#if ($ic > 300) {die "STOP"};
    }
}
close DATAIN     or die "Error closing $filename: $!\n";
