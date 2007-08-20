package Genome::Model::Command::Write::GenotypeSubmission::Ssahasnp;

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
        'version'   => { type => 'String',  doc => "ssahaSNP software version--default is 1.0", is_optional => 1},
        'build'   => { type => 'String',  doc => "reference build version--default is 36", is_optional => 1}
    ], 
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model write genotype-submission ssahasnp --input=ssahaSNP/ccds/H_GW-454_EST_S_8977.out --sample=H_GW-454_EST_S_8977 --basename=ssahasnp_ccds
EOS
}

sub help_brief {
    "create a genotype submission file from ssahaSNP output"
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


#ssaha:SNP 6.1-170975699 0 S6A_2-179o04.q1k C G 40 36 118401548 574 1 118401017 118401706 0 170975699
#(2) subject_name
#(3) index_of_subject
#(4) read_name
#(5) s_base
#(6) q_base
#(7) s_qual
#(8) q_qual
#(9) offset_on_subject
#(10) offset_on_read
#(11) length_of_SNP (==1)
#(12) start_match_of_read
#(13) end_match_of_read
#(14) match_direction
#(15) length_of_subject
#
#
#ssaha:indel S6A_2-179o06.q1k 6.1-170975699 0 145121184 9 0 1 - T 145121175 145121832 1 170975699 29 T 0 - 29 G 29 A
#(2) read_name
#(3) subject_name
#(4) index_of_subject
#(5) offset_on_subject
#(6) offset_on_read
#(7) indel_type_flag ("0" - insertion to the reference; "1" - deletion to
#the ref
#(8) length_of_indel
#(9) q_base
#(10) s_base
#(11) start_match_of_read
#(12) end_match_of_read
#(13) match_direction
#(14) length_of_subject
#(15-22) some quality values for the bases near the indel (may not 100% correct!).

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
		print "Processing $input\n";
		while(<INPUT>) {
			chomp;
			s/\s+/\t/g;
			if (/^ \s* ssaha:SNP/x ) {
#ssaha:SNP 6.1-170975699 0 S6A_2-179o04.q1k C G 40 36 118401548 574 1 118401017 118401706 0 170975699
				my ($type, $subject_name, $index_of_subject, $read_name,
						$s_base, $q_base, $s_qual, $q_qual,
						$offset_on_subject, $offset_on_read,
						$length_of_variation, $start_match_of_read, $end_match_of_read,
						$match_direction, $length_of_subject) = split("\t");
				my $position = $offset_on_subject+1;
				my $key = "$subject_name\t$position\t$q_base";
				$match_direction ||= 1;
				$type =~ s/ssaha://x;

				$variation{$key}{$type}{id} = $subject_name;
				$variation{$key}{$type}{start} = $position;
				$variation{$key}{$type}{end} = $position + ($length_of_variation - 1);
				$variation{$key}{$type}{ref_sequence} = $s_base;
				$variation{$key}{$type}{var_sequence} = $q_base;
				$variation{$key}{$type}{orientation} = ($match_direction) ? 0 : 1;
				$variation{$key}{$type}{subject_index} = $index_of_subject;
				$variation{$key}{$type}{length} = $length_of_variation;
				$variation{$key}{$type}{subject_offset} = $offset_on_subject;
				$variation{$key}{$type}{read_offset} = $offset_on_read;
				$variation{$key}{$type}{subject_quality} = $s_qual;
				$variation{$key}{$type}{read_quality} += $q_qual;
				$variation{$key}{$type}{reads}{$read_name} = 1;
			} elsif (/^ \s* ssaha:indel/x ) {
#ssaha:indel S6A_2-179o06.q1k 6.1-170975699 0 145121184 9 0 1 - T 145121175 145121832 1 170975699 29 T 0 - 29 G 29 A
# ("0" - insertion to the reference; "1" - deletion to the ref
#(15-22) some quality values for the bases near the indel (may not 100% correct!).
				my ($type, $read_name, $subject_name, $index_of_subject,
						$offset_on_subject, $offset_on_read, $indel_type_flag, $length_of_variation,
						$q_base, $s_base, $start_match_of_read, $end_match_of_read,
						$match_direction, $length_of_subject, @near_qual) = split("\t");
				my $position = $offset_on_subject+1;
				my $key = "$subject_name\t$position\t$q_base";
				$match_direction ||= 1;
				$type =~ s/ssaha://x;

				$variation{$key}{$type}{id} = $subject_name;
				$variation{$key}{$type}{start} = $position;
				$variation{$key}{$type}{end} = $position + ($length_of_variation - 1);
				$variation{$key}{$type}{ref_sequence} = $s_base;
				$variation{$key}{$type}{var_sequence} = $q_base;
				$variation{$key}{$type}{orientation} = ($match_direction) ? 0 : 1;
				$variation{$key}{$type}{subject_index} = $index_of_subject;
				$variation{$key}{$type}{length} = $length_of_variation;
				$variation{$key}{$type}{subject_offset} = $offset_on_subject;
				$variation{$key}{$type}{read_offset} = $offset_on_read;
				$variation{$key}{$type}{indel_type} = $indel_type_flag;
				$variation{$key}{$type}{reads}{$read_name} = 1;
			}
		}
		close(INPUT);

		my %output;
		print "Processing variations\n";
		foreach my $key (keys %variation) {
			my ($id, $position, $variant) = split("\t",$key);
			my $chromosome;
			if ($id =~ /NC_0000(.{2})/x ) {
				$chromosome = $1;
			} elsif ($id =~ /chr(.*)$/x) {
				$chromosome = $1;
			}
			my $coord_id = $id;
			if ($id =~ /CCDS/) {
				$coord_id =~ s/\|.*$//;
			}
			my $offset = (exists($coords{$coord_id}{offset})) ?
				(($coords{$coord_id}{offset} > 1) ? $coords{$coord_id}{offset} - 1 : 0 ) : 0;
			$position += $offset;

			$chromosome ||= (defined($coords{$coord_id}{chromosome})) ?
				$coords{$coord_id}{chromosome} : 'Z';
			# left pad with zero so sorting is easy
			if ($chromosome =~ /^ \d+ $/x ) {
				$chromosome = sprintf "%02d", $chromosome;
			}

			$output{$chromosome}{$position}{id} = $id;

			foreach my $var_type (keys %{$variation{$key}}) {
				my @reads = (keys %{$variation{$key}{$var_type}{reads}});
				$output{$chromosome}{$position}{variant_reads} = $#reads + 1;
				if ($var_type eq 'SNP') {
					my $number = (defined($#reads) && $#reads > 0) ? $#reads + 1 : 1;
					$output{$chromosome}{$position}{quality_score} = sprintf "%.0f",
						$variation{$key}{$var_type}{read_quality} / $number;
				}
				foreach my $valuekey (keys %{$variation{$key}{$var_type}}) {
					if ($valuekey eq 'start' || $valuekey eq 'end') {
						$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$var_type}{$valuekey}+$offset;
					} else {
						$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$var_type}{$valuekey};
					}
				}
			}
		}
		undef %variation;
		print "Writing genotype submission file\n";
		my $fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
		unless (defined($fh)) {
			$self->error_message("Unable to open genotype submission file for writing: $basename");
			return;
		}
		my $sample_temp = $sample;
		$sample_temp =~ s/454_EST_S_//x;
		my ($sample_a, $sample_b) = split('-',$sample_temp);
		$sample_b = sprintf "%05d",$sample_b;
		my $sample_id = $sample_a . '-' . $sample_b;
		my $number = 1;
		foreach my $chr (sort (keys %output)) {
			my $chromosome = $chr;
			$chromosome =~ s/^0//;
			foreach my $pos (sort { $a <=> $b } (keys %{$output{$chr}})) {
				my $start = $output{$chr}{$pos}{start};
				my $end = $output{$chr}{$pos}{end};
				my $ref_sequence = $output{$chr}{$pos}{ref_sequence};
				my $var_sequence = $output{$chr}{$pos}{var_sequence};
				my $variant_reads = $output{$chr}{$pos}{variant_reads};
				my $total_reads = $output{$chr}{$pos}{total_reads};
				my $ref_reads;
				if (defined($total_reads) && defined($variant_reads)) {
					$ref_reads = $total_reads - $variant_reads;
				}
#				my $reference = $output{$chr}{$pos}{reference};
#				my $consensus = $output{$chr}{$pos}{consensus};
				my $quality_score = $output{$chr}{$pos}{quality_score};
				my $software = 'ssahaSNP' . $version;
				my $plus_minus = ($output{$chr}{$pos}{orientation}) ? '-' : '+';
				my $genotype_allele1 = $ref_sequence;
				my $genotype_allele2 = $var_sequence;
				$quality_score ||= '';
				my @scores = ($quality_score);
				if (defined($ref_reads) && $ref_reads != 0) {
					push @scores, ("reads1=$ref_reads");
				}
				if (defined($variant_reads) && $variant_reads != 0) {
					push @scores, ("reads2=$variant_reads");
				}

				Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build, $chromosome, $plus_minus, $start, $end,
																																 $sample_id, $genotype_allele1, $genotype_allele2, \@scores, $number++);
			}
		}
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

