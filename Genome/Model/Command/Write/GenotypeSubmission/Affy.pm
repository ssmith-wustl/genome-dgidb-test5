package Genome::Model::Command::Write::GenotypeSubmission::Affy;

use strict;
use warnings;

use UR;
use Command;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'input'   => { type => 'String',  doc => "project alignment (input) file"},
        'basename'   => { type => 'String',  doc => "output genotype submission file prefix basename"},
        'coordinates'   => { type => 'String',  doc => "coordinate translation file", is_optional => 1},
        'version'   => { type => 'String',  doc => "affy software version--default is 1.0", is_optional => 1},
        'build'   => { type => 'String',  doc => "reference build version--default is 36", is_optional => 1}
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

		my($input, $sample, $basename, $coord_file, $version, $build) = 
				 ($self->input, $self->sample, $self->basename, $self->coordinates,
				 $self->version, $self->build);
		return unless ( defined($input) && defined($sample) && defined($basename)
									);
		$version ||= '1.0';
		$build ||= '36';

		my %coords;
		if (defined($coord_file) && -e $coord_file) {
			unless (open(COORD,$coord_file)) {
				$self->error_message("Unable to open coordinates input file: $coord_file");
				return;
			}
			print "Reading coordinate translation file $coord_file\n";
			while(<COORD>) {
				chomp;
				my($coord_id,$coord_offset,$chr,$orient) = split("\t");
				$coords{$coord_id}{offset} = $coord_offset;
				$coords{$coord_id}{chromosome} = $chr;
			}
			close(COORD);
		}

		my %variation;

		unless (open(INPUT,$input)) {
			$self->error_message("Unable to open input file: $input");
			return;
		}
		$| = 1;

		my $sample_temp = $sample;
		$sample_temp =~ s/454_EST_S_//x;
		my ($sample_a, $sample_b) = split('-',$sample_temp);
		$sample_b = sprintf "%05d",$sample_b;
		my $sample_id = $sample_a . '-' . $sample_b;

		print "Processing $input\n";
		print "Writing genotype submission file\n";
		my $fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
		unless (defined($fh)) {
			$self->error_message("Unable to open genotype submission file for writing: $basename");
			return;
		}
		while(<INPUT>) {
			chomp;
			next if (/^SNP_id/x );
			my ($snp_id,$chromosome,$start,$allele1,$allele2,$affy_calls,$score) = split(',');
			my $software = 'affy' . $version;
			my $build_id = 'B' . $build;
			my $plus_minus = '+';
			my @scores = ($score,"affy=$affy_calls");

			Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build_id, $chromosome, $plus_minus, $start, $start,
																																 $sample_id, $allele1, $allele2, \@scores);
		}
		close(INPUT);

		$fh->close();
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

