#! /usr/local/bin/perl -w

my $primer_design_list = "$ARGV[0]";
my $validation_list = "$ARGV[1]";
# Open SNP Input
unless (open(PR_IN,"<$primer_design_list")) {
	die "Could not open input file '$primer_design_list' for reading";
}
# Open Output
unless (open(VA_IN,"<$validation_list")) {
	die "Could not open output file '$validation_list' for reading";
  }

unless (open(VA_FAIL_OUT,">$validation_list.fail")) {
	die "Could not open output file '$validation_list'.fail for writing";
  }


my $cue = 0;
my %validated="";
#my ($chr, $start,$stop, $line) = ("","","","");
while( my $line = <VA_IN> ) {
    	if ($line !~ /^Chr/){
		$validated{$line} =1;
	}else{
		next;
	}
}
	
#my ($chr, $start,$stop, $line) = ("","","","");
while( my $line = <PR_IN> ) {
    	if ($line !~ /^Chr/){
		if (!exists $validated{$line}){
			print VA_FAIL_OUT "$line";
		}
	}else{
		next;
	}
}	

close PR_IN;
close VA_FAIL_OUT;
close VA_IN;
