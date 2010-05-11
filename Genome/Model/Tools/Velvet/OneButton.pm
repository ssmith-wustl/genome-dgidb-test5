package Genome::Model::Tools::Velvet::OneButton;
use strict;
use warnings;

use Genome;
use Getopt::Long;
use POSIX;

class Genome::Model::Tools::Velvet::OneButton {
    is => 'Command',
    has => [
        output_dir          => {    is => 'Text',
                                    doc => 'the directory for the results' 
                                }, #|o=s" => \$output_path, 

        genome_len          => {    is => 'Integer',
                                    doc => 'estimated genome length in bases'
                                }, #|g=i" => \$genome_len, 

        hash_sizes          => {    is => 'Integer', is_many => 1, }, #|h=i{,}" => \@hash_sizes, 


        ins_length          => {    is => 'Integer',
                                    doc => 'fragment length (average/estimated)'
                                }, #|i=i" => \$ins_length, 



        version             => {    is => 'Text',
                                    default_value => '57-64',
                                    doc => 'the version of velvet to use'
                                }, #=s" => \$version

        file                => {    shell_args_position => 1,
                                    doc => 'the input fasta or fastq file'
                                },
    ],
    has_optional => [
        bound_enumeration   => {    is => 'Integer',
                                    doc => 'conduct binary search only if the number of candidates greater than b, or conduct enumeration'
                                }, #|b=i" => \$enumeration_bound, 

        dev_ins_length      => {    is => 'Integer',
                                    doc => 'fragment length std deviation'
                                }, #|d=i" => \$ins_length_sd,  

        exp_covs            => {    is => 'Float', is_many => 1, }, #|e=f{,}" => \@exp_covs, 

        cov_cutoffs         => {    is => 'Float', is_many => 1, }, #|c=f{,}" => \@cov_cutoffs,
    ],
    doc => 'run velvet in a smart way (under conversion from initial script)'
};

sub help_synopsis {
    return <<EOS
gmt velvet one-button foo.fast[a|q] \
    [-o output_directory] \ 
    [-g genome_length] \
    [-h 31,33,35 ] \
    [-e exp_cov1 2,.. ] \
    [-c cov_cutoff1 2,.. ] \
    [-i insert_length] \
    [-d ins_length_sd] \
    [-b enumeration_bound] \
    [--version 57-64 #for velvet_0.7.57-64, only input the part behind velvet_0.7.);

ADD MORE EXAMPLES HERE!!!!
EOS
}

sub help_detail {
    return "A wrapper for running velvet based on the original oneButtonVelvet-3opts by Guohui Yao.\n\nCONVERSION STILL IN PROGRESS.  CONTACT INFORMATICS!"
}


use vars qw/$genome_len @hash_sizes @exp_covs @cov_cutoffs $ins_length $ins_length_sd $data_fullname $output_path $enumeration_bound $version/;

my $velveth = "velveth";
my $velvetg = "velvetg";
my $version_path = "/gsc/pkg/bio/velvet/velvet_0.7.";

my $defined_cov_cutoffs;
my $defined_exp_covs;
my $defined_genome_len;

# Global variables
my ($hash_size, $exp_cov, $cov_cutoff);
# keep the best result and corresponding params
my (@best_n50total, $best_hash_size, $best_exp_cov, $best_cov_cutoff);
#the best result for each hash size
my (@hbest_n50total, $hbest_exp_cov, $hbest_cov_cutoff);

my $name_prefix;
my @fields;
my $data_name;
my $logfile;
my $screen_g;
my $lastline;

my ($read_len, $read_num, $file_format);

sub execute {
    my $self = shift;

    #die "CONVERSION STILL IN PROGRESS!!!!  (contact informatics)";

    $output_path    = $self->output_dir;
    $genome_len     = $self->genome_len;
    @hash_sizes     = $self->hash_sizes;
    @exp_covs       = $self->exp_covs;
    @cov_cutoffs   = $self->cov_cutoffs;
    $ins_length     = $self->ins_length;
    $ins_length_sd  = $self->dev_ins_length;
    $enumeration_bound = $self->bound_enumeration;
    $version        = $self->version;

    $data_fullname = $self->file;

    #    output_dir          => {}, #|o=s" => \$output_path, 
    #    genome_len          => {}, #|g=i" => \$genome_len, 
    #    hash_sizes          => {}, #|h=i{,}" => \@hash_sizes, 
    #    exp_covs            => {}, #|e=f{,}" => \@exp_covs, 
    #    cov_cutoff          => {}, #|c=f{,}" => \@cov_cutoffs, 
    #    ins_length          => {}, #|i=i" => \$ins_length, 
    #    dev_ins_length      => {}, #|d=i" => \$ins_length_sd,  
    #    bound_enumeration   => {}, #|b=i" => \$enumeration_bound, 
    #    version             => {}, #=s" => \$version

    #GetOptions(
    #    "output_dir|o=s" => \$output_path, 
    #    "genome_len|g=i" => \$genome_len, 
    #    "hash_sizes|h=i{,}" => \@hash_sizes, 
    #    "exp_covs|e=f{,}" => \@exp_covs, 
    #    "cov_cutoff|c=f{,}" => \@cov_cutoffs, 
    #    "ins_length|i=i" => \$ins_length, 
    #    "ins_length_sd|d=i" => \$ins_length_sd,  
    #    "enumeration_bound|b=i" => \$enumeration_bound, 
    #    "version=s" => \$version
    #);
    
    #$data_fullname or die("Please gave the file name.\n");
    
    # Choose velvet version
    $velveth = $version_path . $version . "/velveth" if $version;
    $velvetg = $version_path . $version . "/velvetg" if $version;
    
    
    # default parameters
    $output_path or chomp($output_path = `pwd`);
    @hash_sizes or @hash_sizes = (25, 27, 29);
    $ins_length or $ins_length = 280;
    $ins_length_sd or $ins_length_sd = 0.2*$ins_length;
    $enumeration_bound or $enumeration_bound = 5;
    $defined_cov_cutoffs = defined(@cov_cutoffs);
    $defined_exp_covs = defined(@exp_covs);
    $defined_genome_len = defined($genome_len);                                  

    defined($genome_len) or $genome_len = 3000000; #$genome_len = 1000;
    
    # sort candidates for each param
    @hash_sizes = sort {$a <=> $b} @hash_sizes;
    @exp_covs = sort {$a <=> $b} @exp_covs if $defined_exp_covs;
    @cov_cutoffs = sort {$a <=> $b} @cov_cutoffs if $defined_cov_cutoffs;
    
    
    
    
    ##------------------------------------
    ## Make a new name for result file 
    ##------------------------------------

    
    $name_prefix = &use_date_as_name;
    @fields = split(/\//, $data_fullname);
    $data_name = $fields[@fields-1];
    $output_path =~ s/\/$//g;
    $name_prefix = "$output_path/$name_prefix-$data_name";
    $logfile = "$name_prefix-logfile";											# keep task, velveth, hbest, velvetg, n50toal
    $screen_g = "$output_path/screen_g";
    $lastline = "$output_path/lastline";
    #die("testing $logfile, exit\n");
    
    
    &echo_params_to_screen_logfile;
    
    
    ##-----------------------------------------------------##
    ## Get read length, number of reads and file format 
    ##-----------------------------------------------------##
    
    ($read_len, $read_num, $file_format) = &get_read_len_num_and_file_format;
    system("echo '\#read length: $read_len\n\#number of reads: $read_num' >> $logfile");
    print "read length: $read_len\n";
    print "number of reads: $read_num\n";
    print "File format: $file_format\n";
    #die("test read len, num and file format! now exit!\n");
    
    
    
    ##-----------------------------------
    ## Command Line
    ##-----------------------------------
    
    #my $cmdh = "velveth $output_path $hash_size $file_format -shortPaired $data_fullname";
    #my $cmdg = "velvetg $output_path -exp_cov $exp_cov -cov_cutoff $cov_cutoff -ins_length $ins_length -ins_length_sd $ins_length_sd";
    
    
    ##-----------------------------##
    ## Pick best param combination ##
    ##-----------------------------##
    
    @best_n50total = (0, 0);
    if(@hash_sizes > $enumeration_bound){
        &pick_best_hash_size(@hash_sizes);
    }else{
        &enum_hash_size;
    }
    print "The best result is: (hash_size exp_cov cov_cutoff n50 total)\n";
    print join(" ", ($best_hash_size, $best_exp_cov, $best_cov_cutoff, @best_n50total));
    print "\n";
    print `date`;
    
    unlink("$lastline") if -e "$lastline";
    unlink("$screen_g") if -e "$screen_g";
    
    
    #add 3 options
    
    my $last_cmdh = "$velveth $output_path $best_hash_size $file_format -shortPaired $data_fullname";
    system("echo $last_cmdh >> $logfile");
    system("$last_cmdh");
    
    my $last_cmdg = "$velvetg $output_path -exp_cov $best_exp_cov -cov_cutoff $best_cov_cutoff -ins_length $ins_length -ins_length_sd $ins_length_sd -read_trkg yes -min_contig_lgth 100 -amos_file yes";
    system("echo $last_cmdg >> $logfile");
    system("$last_cmdg");
   
    return 1;

}

##############################################################################

##---------------------------------------------
## Utility Functions 
## run_velvetg to get n50 and total length
## run_velveth 
## enum_hash_size
## pick_best_hash_size
## pick_best_exp_cov
## pick_best_cov_cutoff
## better
## get_read_len_num_and_file_format
## use_date_as_name
## echo_params_to_screen_logfile
##---------------------------------------------


sub run_velvetg_get_n50total{
	$#_ > -1 or die("run_velvetg_get_n50total expects one parameter: cov_cutoff\n");
	$cov_cutoff = $_[0];
	my $cmdg = "$velvetg $output_path -exp_cov $exp_cov -cov_cutoff $cov_cutoff -ins_length $ins_length -ins_length_sd $ins_length_sd";
	print "$cmdg\n";
	system("echo $cmdg >> $logfile");
	system("$cmdg > $screen_g");
	system("tail -1 $screen_g > $lastline");

	open LAST, "$lastline" or die("Bad file $lastline\n");
	my $line = <LAST>;
	close LAST;
	($line =~ /n50 of (\d+).*total (\d+)/) or die("Error: extract n50 and total from $lastline\n");
	
	my @n50total = ($1, $2);
	print join(" ", @n50total)."\n";
	system("echo @n50total >> $logfile");
	if(&better(@n50total, @best_n50total) == 1){
		@best_n50total = @n50total;
		$best_exp_cov = $exp_cov;
		$best_cov_cutoff = $cov_cutoff;
		$best_hash_size = $hash_size;
		system("cp $output_path/contigs.fa $name_prefix-contigs.fa");
	}
	if(&better(@n50total, @hbest_n50total) == 1){
		@hbest_n50total = @n50total;
		$hbest_exp_cov = $exp_cov;
		$hbest_cov_cutoff = $cov_cutoff;
		system("mv $output_path/contigs.fa $name_prefix-hash_size_$hash_size-contigs.fa");
	}
	@n50total;
}

sub run_velveth_get_opt_expcov_covcutoff{
	$#_ > -1 or die("run_velveth_get_opt_expcov_covcutoff expects a parameter: hash_size\n");
	$hash_size = $_[0];
	print "Try hash size: $hash_size\n";
	@hbest_n50total = (0, 0);

#	Run velveth
	my $cmdh = "$velveth $output_path $hash_size $file_format -shortPaired $data_fullname";
	print "$cmdh\n";
	system("echo $cmdh >> $logfile");
	system("$cmdh");

#	Approximating Genome Length
	my $ck = $read_num*($read_len-$hash_size+1)/$genome_len;						# 3M or approx with former h
	($defined_exp_covs) ? ($exp_cov = $exp_covs[floor($#exp_covs/2)]) : ($exp_cov = 0.9*$ck);
	($defined_cov_cutoffs) ? ($cov_cutoff = $cov_cutoffs[floor($#cov_cutoffs/2)]) : ($cov_cutoff = 0.1*$exp_cov);
	(my $n50,$genome_len) = &run_velvetg_get_n50total($cov_cutoff);
	print "genome length: $genome_len\n";

#	get optimal exp_cov and cov_cutoff
	@hbest_n50total = (0, 0);	#ignore the one generated during approximating genome length
	$ck = $read_num*($read_len-$hash_size+1)/$genome_len;
	&pick_best_exp_cov($ck);										# $ck used to make exp_covs
	my @hbest = ($hash_size, $hbest_exp_cov, $hbest_cov_cutoff, @hbest_n50total);
	print join(" ", @hbest)."\n";
	system("echo @hbest >> $logfile");
	system("cat $output_path/Log >> $name_prefix-timing");
	@hbest_n50total;
}

sub enum_hash_size {
	foreach my $h (@hash_sizes){
		&run_velveth_get_opt_expcov_covcutoff($h);
	}	
}

sub pick_best_hash_size{
	$#_ > -1 or die("pick_best_hash_size expects params: hash_sizes\n");
	@hash_sizes = @_;
	my $start = 0;
	my $end = $#hash_sizes;
	my $mid = floor(0.5*($start+$end));
	my $low = floor(0.5*($start+$mid));
	my $high = ceil(0.5*($mid+$end));
	my @mid_pair = (0, 0);
	my @low_pair = (0, 0);
	my @high_pair = (0, 0);

	@mid_pair = &run_velveth_get_opt_expcov_covcutoff($hash_sizes[$mid]);		#	$hash_size = $hash_sizes[$mid];
	while($start < $end) {
		($start == $mid) ? (@low_pair = @mid_pair) : (@low_pair = (0, 0));
		($end == $mid) ? (@high_pair = @mid_pair) : (@high_pair = (0, 0));
		
		$low_pair[0] or @low_pair = &run_velveth_get_opt_expcov_covcutoff($hash_sizes[$low]);
		if(&better(@low_pair, @mid_pair) == 1) {
			$end = $mid-1;
			$mid = $low;
			@mid_pair = @low_pair;
		}
		else {
			$high_pair[0] or @high_pair = &run_velveth_get_opt_expcov_covcutoff($hash_sizes[$high]);			
			if( (&better(@high_pair,@low_pair) == 1) or
			((&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == -1)) ){
				$start = $mid+1;
				$mid = $high;
				@mid_pair = @high_pair;
			}elsif( (&better(@high_pair,@mid_pair) == -1) and (&better(@low_pair,@mid_pair) == 0) ){
				$end = $mid-1;
				$mid = $low;
				@mid_pair = @low_pair;
			}elsif( (&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == 0) ){
				splice(@hash_sizes, $low+1, $high-$low);
				$end -= ($high-$low);
				$mid = $low;
				@mid_pair = @low_pair;
			}else{	#low < mid, high < mid
				$start = $low+1;
				$end = $high-1;
			}			
		}
		$low = floor(0.5*($start+$mid));
		$high = ceil(0.5*($mid+$end));
	}
	@mid_pair;
}

sub pick_best_exp_cov{
	$#_ > -1 or die("pick_best_exp_cov expects one parameter: C_k\n");
	my $ck = $_[0];																#	print "exp_cov(ck) = $ck\n";
	$defined_exp_covs or @exp_covs = (floor(0.8*$ck)..floor($ck/0.95));
	my $start = 0;
	my $end = $#exp_covs;
	my $mid = floor(0.5*($start+$end));
	my $low = floor(0.5*($start+$mid));
	my $high = ceil(0.5*($mid+$end));
	my @mid_pair = (0,0);
	my @low_pair = (0,0);
	my @high_pair = (0,0);
	
	@mid_pair = &pick_best_cov_cutoff($exp_covs[$mid]);
	while($start < $end) {
		($start == $mid) ? (@low_pair = @mid_pair) : (@low_pair = (0, 0));		#low == mid
		($end == $mid) ? (@high_pair = @mid_pair) : (@high_pair = (0, 0));		#high == mid
		
		$low_pair[0] or @low_pair = &pick_best_cov_cutoff($exp_covs[$low]);
		if(&better(@low_pair, @mid_pair) == 1) {
			$end = $mid-1;
			$mid = $low;
			@mid_pair = @low_pair;
		}
		else {	# low <= mid
			$high_pair[0] or @high_pair = &pick_best_cov_cutoff($exp_covs[$high]);
			if( (&better(@high_pair,@low_pair) == 1) or
			((&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == -1)) ){
				$start = $mid+1;
				$mid = $high;
				@mid_pair = @high_pair;
			}elsif( (&better(@high_pair,@mid_pair) == -1) and (&better(@low_pair,@mid_pair) == 0) ){
				$end = $mid-1;
				$mid = $low;
				@mid_pair = @low_pair;
			}elsif( (&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == 0) ){
				splice(@exp_covs, $low+1, $high-$low);
				$end -= ($high-$low);
				$mid = $low;
				@mid_pair = @low_pair;
			}else{	#low < mid, high < mid
				$start = $low+1;
				$end = $high-1;
			}
		}
		$low = floor(0.5*($start+$mid));
		$high = ceil(0.5*($mid+$end));
	}
	@mid_pair;	
}


sub pick_best_cov_cutoff {
	$#_ > -1 or die("pick_best_cov_cutoff expects one parameter: exp_cov\n");
	$exp_cov = $_[0];															#	print "Try exp_cov = $exp_cov\n";
	$defined_cov_cutoffs or @cov_cutoffs = (0..floor(0.3*$exp_cov));
	my $start = 0;
	my $end = $#cov_cutoffs;
	my $mid = floor(0.5*($start+$end));
	my $low = floor(0.5*($start+$mid));
	my $high = ceil(0.5*($mid+$end));
	my @mid_pair = (0,0);
	my @low_pair = (0,0);
	my @high_pair = (0,0);

	if(@cov_cutoffs > $enumeration_bound){										#conduct binary seach
		@mid_pair = &run_velvetg_get_n50total($cov_cutoffs[$mid]);				#my $runs = 0;
		while($start < $end) {
			($start == $mid) ? (@low_pair = @mid_pair) : (@low_pair = (0, 0));	#low == mid
			($end == $mid) ? (@high_pair = @mid_pair) : (@high_pair = (0, 0));	#high == mid	
			$low_pair[0] or @low_pair = &run_velvetg_get_n50total($cov_cutoffs[$low]);
			if(&better(@low_pair,@mid_pair) == 1){								#low > mid
				$end = $mid-1;
				$mid = $low;
				@mid_pair = @low_pair;
			}
			else{	#low <= mid
				$high_pair[0] or @high_pair = &run_velvetg_get_n50total($cov_cutoffs[$high]);
				if( (&better(@high_pair, @mid_pair) == 1) or 
				((&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == -1)) ){
					$start = $mid+1;
					$mid = $high;
					@mid_pair = @high_pair;
				}elsif( (&better(@high_pair,@mid_pair) == -1) and (&better(@low_pair,@mid_pair) == 0) ){
					$end = $mid-1;
					$mid = $low;
					@mid_pair = @low_pair;
				}elsif( (&better(@high_pair,@mid_pair) == 0) and (&better(@low_pair,@mid_pair) == 0) ){
					splice(@cov_cutoffs, $low+1, $high-$low);
					$end -= ($high-$low);
					$mid = $low;
					@mid_pair = @low_pair;
				}else{	#low < mid, high < mid
					$start = $low+1;
					$end = $high-1;
				}
			}
			$low = floor(0.5*($start+$mid));
			$high = ceil(0.5*($mid+$end));
		}#while
	}else{ # enumerate all cov_cutoffs
		foreach my $cov_cutoff (@cov_cutoffs){
			@low_pair = &run_velvetg_get_n50total($cov_cutoff);
			if(&better(@low_pair, @mid_pair) == 1){
				@mid_pair = @low_pair;
			}
		}	
	}

	@mid_pair;
}

sub better {
	if(@_ != 4){
		print @_."\n";
		print join(" ",@_)."\n";
		die("The parameters of func better should be two pairs\n");
	} 
	my($n1, $t1, $n2, $t2) = @_;
	if(($t1 < 0.95*$genome_len or $genome_len < 0.95*$t1) and
	   ($t2 < 0.95*$genome_len or $genome_len < 0.95*$t2)){0;}					# both wrong length
	elsif($t1 < 0.95*$genome_len or $genome_len < 0.95*$t1){-1;}				# t1 is wrong
	elsif($t2 < 0.95*$genome_len or $genome_len < 0.95*$t2){1;}					# t2 is wrong
	elsif($n1 > $n2){1;}														# n1 is better
	elsif($n1 < $n2){-1;}														# n2 is better
	else{0;}																	# n1 == n2
}

sub get_read_len_num_and_file_format {
	my $read_len; 
	my $read_num = 0;
	my $total_len = 0;
	my $file_format = "-fasta";

	open (IN, $data_fullname) or die ("Bad file $data_fullname\n");
	my $line = <IN>;
	if($line =~ /^\>/) { $file_format = "-fasta"; }
	elsif($line =~ /^\@/) { $file_format = "-fastq"; }
	else { die("Error: file format should be either fasta or fastq."); }

	if($file_format eq "-fasta"){
		$read_num++;
		while(<IN>) {
			if(/^\>/){
				$read_num++;
			}
			else{
				$total_len += length()-1;
			}
		}#while
	}#fasta
	elsif($file_format eq "-fastq"){
		while($line) {
			unless($line =~ /^\@/) {exit("Error: more than one line in a single read.");}
			$read_num++;
			$line = <IN>;
			$total_len += length($line)-1;
			for my $i (0..2) {$line = <IN>;}									#Escape 2 lines
		}
	}
	close IN;
	$read_len = $total_len/$read_num;
	($read_len, $read_num, $file_format);
}


sub use_date_as_name {
	my $name_prefix = `date`;
	chop($name_prefix);
	$name_prefix =~ s/CDT //;
	$name_prefix =~ s/ /-/g;
	$name_prefix =~ s/:\d\d-/-/g;
	$name_prefix =~ s/://g;
	$name_prefix;
}

sub echo_params_to_screen_logfile{
	print `date`;
	print "Your parameters:\n";
	print "hash sizes = @hash_sizes\n";
	print "exp_covs = @exp_covs\n" if defined(@exp_covs);
	print "cov_cutoffs = @cov_cutoffs\n" if defined(@cov_cutoffs);
	print "genome length = $genome_len\n" if $defined_genome_len;
	print "ins_length = $ins_length\n";
	print "ins_length_sd = $ins_length_sd\n";
	print "input file = $data_fullname\n";
	print "output directory = $output_path\n";
	print "enumeration bound = $enumeration_bound\n";
	print "version = $version_path$version\n" if $version;

	system("echo '\#Your parameters:\n\#hash_sizes: @hash_sizes' >> $logfile");
	system("echo '\#exp_covs: @exp_covs' >> $logfile");
	system("echo '\#cov_cutoffs: @cov_cutoffs' >> $logfile");
	system("echo '\#genome length: $genome_len' >> $logfile");
	system("echo '\#ins_length: $ins_length' >> $logfile");
	system("echo '\#ins_length_sd: $ins_length_sd' >> $logfile");
	system("echo '\#input file: $data_fullname' >> $logfile");
	system("echo '\#output directory: $output_path' >> $logfile");
	system("echo '\#enumeration_bound: $enumeration_bound' >> $logfile");
	system("echo '\#version: $version_path$version' >> $logfile") if $version;
}

1;
