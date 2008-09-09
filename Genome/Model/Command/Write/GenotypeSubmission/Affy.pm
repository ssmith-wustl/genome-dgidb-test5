package Genome::Model::Command::Write::GenotypeSubmission::Affy;

use strict;
use warnings;

use Genome;
use Command;
use File::Path;
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'normsample'   => { type => 'String',  doc => "normal sample name", is_optional => 1},
        'sample'   => { type => 'String',  doc => "sample name"},
        'input'   => { type => 'String',  doc => "project alignment (input) file"},
        'absnp'   => { type => 'String',  doc => "ab snp file (input) file", is_optional => 1},
        'basename'   => { type => 'String',  doc => "output genotype submission file prefix basename"},
        'coordinates'   => { type => 'String',  doc => "coordinate translation file", is_optional => 1},
        'offset'   => { type => 'String',  doc => "coordinate offset to apply--default is zero", is_optional => 1},
        'version'   => { type => 'String',  doc => "affy software version--default is ''", is_optional => 1},
        'verbose'   => { type => 'Boolean',  doc => "print progress messages", is_optional => 1},
        'build'   => { type => 'String',  doc => "reference build version--default is 36", is_optional => 1},
        'loaddb'   => { type => 'Boolean',  doc => "load to the database--default is to produce a file", is_optional => 1},
        'check'   => { type => 'Boolean',  doc => "processing check only the input file", is_optional => 1},
        'rccheck'   => { type => 'Boolean',  doc => "revcomp check against the consensus--set check", is_optional => 1},
        'verbose'   => { type => 'Boolean',  doc => "print progress messages", is_optional => 1},
        'source'   => { type => 'String',  doc => "set source--default is 'wugsc'", is_optional => 1},
        'techtype'   => { type => 'String',  doc => "set tech_type--default is 'solexa'", is_optional => 1},
        'mappingreference'   => { type => 'String',  doc => "set mapping_reference--default is 'hg'", is_optional => 1},
        'runidentifier'   => { type => 'String',  doc => "set run_identifier--default is null", is_optional => 1}
    ], 
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model write genotype-submission affy --input=affyfile --sample=H_GW-454_EST_S_8977 --basename=affy
EOS
}

sub help_brief {
    "create a genotype submission file from Ken's converted affy file"
}

sub help_detail {                       
    return <<EOS 

EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}


sub execute {
	my $self = shift;
	
	my($input, $norm_sample_id, $sample_id, $absnp,
		 $basename, $version, $build, $coord_offset) = 
			 ($self->input, $self->normsample, $self->sample, $self->absnp,
				$self->basename, $self->version, $self->build, $self->offset);
	return unless ( defined($input) && defined($sample_id) && defined($basename)
								);
	$version ||= '';
	$build ||= '36';
	$coord_offset ||= 0;
	
	my ($check, $rccheck, $verbose, $source, $techtype, $mappingreference, $runidentifier) =
		($self->check, $self->rccheck, $self->verbose, $self->source,
		 $self->techtype, $self->mappingreference, $self->runidentifier);
	$check ||= 0;
	$rccheck ||= 0;
	$techtype ||= 'solexa';
	$mappingreference ||= 'hg';
	my %variation;
	
	my $fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
	unless (defined($fh)) {
		$self->error_message("Unable to open genotype submission file for writing: $basename");
		return;
	}
	
	unless (open(INPUT,$input)) {
		$self->error_message("Unable to open input file: $input");
		return;
	}
	$| = 1;
	
	my $mutation = {};
	my $number = 1;
	if (defined($absnp)) {
		unless (open(ABSNP,$absnp)) {
	    $self->error_message("Unable to open input file: $absnp");
	    return;
		}
		my %ab;
		my %chr;
		if ($verbose) {
			print "Reading $absnp\n";
		}
		while (<ABSNP>) {
	    chomp;
	    my ($id, $chr, $a, $b) = split("\t");
	    $ab{"$id\tA"} = $a;
	    $ab{"$id\tB"} = $b;
	    $chr{$id} = $chr;
		}
		close(ABSNP);
		
		if ($verbose) {
			print "Processing $input\n";
			print "Writing genotype submission file\n";
		}
		my $head = <INPUT>;
		$head = <INPUT>;
		my $software = 'affy' . $version;
		my $build_id = $build;
		my $plus_minus = '+';
		while(<INPUT>) {
	    chomp;
	    s/\r//g;
	    my ($line, $snp_id, $chromosome, $position, $dbsnp_id, $norm_call, $norm_conf, $tumor_call, $tumor_conf) = split("\t");
	    $position += $coord_offset; # add a user supplied offset--the position is still undef  if undef
	    unless ($chromosome =~ /^ [\dXY]+ $/x) {
				if (defined($chr{$snp_id})) {
					$chromosome = $chr{$snp_id};
				}
	    }
	    unless ($chromosome =~ /^ [\dXY]+ $/x) {
				print "Unknown chromosome: $chromosome ...skipping\n";
				next;
	    }
	    my ($abkey1, $abkey2, $allele1, $allele2);
	    
	    $abkey1 = "$snp_id\t" . substr($norm_call,0,1);
	    $abkey2 = "$snp_id\t" . substr($norm_call,1,1);
	    $allele1 = $ab{$abkey1};
	    $allele2 = $ab{$abkey2};
	    if (defined($allele1) && defined($allele2)) {
				Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build_id, $chromosome, $plus_minus, $position, $position,
																																 $norm_sample_id, $allele1, $allele2, [ $norm_conf ]);
	    } else {
				print "No AB record for SNP: $snp_id $norm_call\n";
	    }
	    
	    $abkey1 = "$snp_id\t" . substr($tumor_call,0,1);
	    $abkey2 = "$snp_id\t" . substr($tumor_call,1,1);
	    $allele1 = $ab{$abkey1};
	    $allele2 = $ab{$abkey2};
	    if (defined($allele1) && defined($allele2)) {
				Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build_id, $chromosome, $plus_minus, $position, $position,
																																 $sample_id, $allele1, $allele2, [ $tumor_conf ]);
				if ($self->loaddb) {
					$mutation = MG::IO::GenotypeSubmission::AddMutation($mutation,$software,$build_id,
																															$chromosome, $plus_minus,
																															"$position", "$position",
																															$sample_id, 
																															$allele1, $allele2,
																															[ $tumor_conf ], $number);
				}
				$number += 1;
	    } else {
				print "No AB record for SNP: $snp_id $tumor_call\n";
	    }
		}
	} else {
		if ($verbose) {
			print "Processing $input\n";
			print "Writing genotype submission file\n";
		}
		my $sample_temp = $sample_id;
		my ($sample_a, $sample_b) = split('-',$sample_temp);
		$sample_b = sprintf "%05d",$sample_b;
		my $sample_id = $sample_a . '-' . $sample_b;
		while(<INPUT>) {
	    chomp;
			s/\r//g;
	    next if (/^SNP_id/x );
	    my ($snp_id,$chromosome,$start,$allele_a,$allele_b,$affy_calls,$score) = split(',');
			my ($allele1, $allele2);
			$allele1 = $allele_a;
	    my @scores = ($score,"affy=$affy_calls");
			if ($affy_calls == 0) {		# AA
				$allele2 = $allele_a;
			} elsif ($affy_calls == 1) { # AB
				$allele2 = $allele_b;
			} elsif ($affy_calls == 2) { # BB
				$allele2 = $allele_b;
				push @scores, ("cns=$allele_b");
			} else {
				next;
			}
	    unless ($chromosome =~ /^ [\dXY]+ $/x) {
				print "Unknown chromosome: $chromosome $_ ...skipping\n";
				next;
	    }
	    my $software = 'affy' . $version;
	    my $build_id = $build;
	    my $plus_minus = '+';
	    
	    Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build_id, $chromosome, $plus_minus, $start, $start,
																															 $sample_id, $allele1, $allele2, \@scores);
			if ($self->loaddb) {
				$mutation = MG::IO::GenotypeSubmission::AddMutation($mutation,$software,$build_id,
																														$chromosome, $plus_minus,
																														"$start", "$start",
																														$sample_id, 
																														$allele1, $allele2,
																														\@scores, $number);
			}
			$number += 1;
		}
	}
	close(INPUT);
	$fh->close();
	my $t0 = time;
	if ($self->loaddb) {
		if ($verbose) {
			print "Loading database\n";
		}
		$t0 = MG::IO::GenotypeSubmission::LoadDatabase($mutation,
																									 check => $check,
																									 rccheck => $rccheck,
																									 verbose => $verbose,
																									 source => $source,
																									 tech_type => $techtype,
																									 mapping_reference => $mappingreference,
																									 run_identifier => $runidentifier
																									);
	}
	#####################
	#  POST PROCESSING  #
	#####################
	
	#__VERBOSE OUTPUT OF PROGRESS
	if ($verbose) {
		my $elapsed = time - $t0;
		print "\nDONE: elapsed time $elapsed secs\n";
	}
	return 1;
}





#	'ssaha:SNP';
#	'ssaha:indel';
#
#Score     Q_Name             S_Name            Q_Start    Q_End  S_Start    S_En
#d Direction #Bases identity
#224   ESJ9UC401AIBHS CCDS11830.1|Hs36.2|chr18        1      228       216
#443   F     228 99.56 231
#ProcessSNP_start ESJ9UC401AIBHS
#snp_start CCDS11830.1|Hs36.2|chr18_322
#($score, $q_name, $s_name, $q_start, $q_end, $s_start, $s_end, $direction, $num_bases, $identity)
# score: 224: q_name ESJ s_name: CCDS q_start: 1 q_end: 228 s_start: 216 s_end: 443 direction: F num_bases: 228 identity
#ssaha:SNP CCDS11830.1|Hs36.2|chr18 11068 ESJ9UC401AIBHS T C 40 28 321 106 1 216 443 0 516
#          ref_id(1)                   start(2) q_id(3)           r(4) v(5)
#(6) (7) (8) (9) (10)
#offset(11) offseted(12) rcdex(13) sub_length(14)
#
#
#s_name snp_ctgid r_name query_base subject_base 6  7  snp_start snp_rdpos 10 ref_start ref_end snp_rcdex snp_length
#chr18 11068 ESJ9UC401    T           C          40 28 321        106      1  216       443     0         516

1;

