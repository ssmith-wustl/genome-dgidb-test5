package Genome::Model::Command::Write::GenotypeSubmission::Maq;

use strict;
use warnings;

use UR;
use Command;
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'mapfile'   => { type => 'String',  doc => "maq map file"},
        'cnsfile'   => { type => 'String',  doc => "maq cns file"},
        'refbfa'   => { type => 'String',  doc => "reference bfa file"},
        'basename'   => { type => 'String',  doc => "output genotype submission file prefix basename"},
        'coordinates'   => { type => 'String',  doc => "coordinate translation file", is_optional => 1},
        'indel'   => { type => 'Boolean',  doc => "try to get indel's also (not implemented yet)", is_optional => 1},
        'version'   => { type => 'String',  doc => "maq software version--default is 0.5", is_optional => 1},
        'build'   => { type => 'String',  doc => "reference build version--default is 36", is_optional => 1},
        'db'   => { type => 'String',  doc => "load to the database--default is to produce a file", is_optional => 1}
    ]
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model write genotype-submission maq --mapfile=my.map --refbfa=ref.bfa --sample=H_GW-454_EST_S_8977 --basename=username
EOS
}

sub help_brief {
    "create a genotype submission file from maq output"
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

		my($mapfile, $cnsfile, $refbfa, $sample, $basename, $coord_file,
			 $indel, $version, $build) =
			($self->mapfile, $self->cnsfile, $self->refbfa, $self->sample, $self->basename,
			 $self->coordinates, $self->indel, $self->version, $self->build);
		return unless ( defined($mapfile) && defined($cnsfile) && defined($refbfa) &&
										defined($sample) && defined($basename)
									);
		$version ||= '0.5';
		$build ||= '36';

		$| = 1;											# autoflush stdout

		my $genomic_coords = MG::Transform::Coordinates::TranscriptToGenomic->new(
																																						 coordinate_file => $coord_file);

		my $snp_cmd = "maq cns2snp $cnsfile |";
		unless (open(SNP,$snp_cmd)) {
			$self->error_message("Unable to run input command: $snp_cmd");
			return;
		}
		my %variation;
		print "Processing $cnsfile for SNPs\n";
		while(<SNP>) {
			chomp;
			my ($id, $start, $ref_sequence, $var_sequence, $quality_score, $depth, $avg_hits, $high_quality, $unknown) = split("\t");
			my $key = "$id\t$start";
			$variation{$key}{start} = $start;
			$variation{$key}{end} = $start;
			$variation{$key}{ref_sequence} = $ref_sequence;
			$variation{$key}{var_sequence} = $var_sequence;
			$variation{$key}{quality_score} = $quality_score;
			$variation{$key}{variant_reads} = $depth;
			$variation{$key}{avg_hits} = $avg_hits;
			$variation{$key}{high_quality} = $high_quality;
			$variation{$key}{unknown} = $unknown;
		}
		close(SNP);
		my $pileup_cmd = "maq pileup -v $refbfa $mapfile |";
		unless (open(PILEUP,$pileup_cmd)) {
			$self->error_message("Unable to run input command: $pileup_cmd");
			return;
		}
		my $count = 0;
		print "Processing $mapfile for pileup ";
		while(<PILEUP>) {
			chomp;
			my ($id, $position, $ref_base, $depth, $bases) = split("\t");
			if ($depth > 0) {
				my $key = "$id\t$position";
				if	(defined($variation{$key})) {
					print '.' if (++$count % 1000 == 0);
					$variation{$key}{total_reads} = $depth;
#					$variation{$key}{ref_base} = $ref_base;
#					$variation{$key}{bases} = $bases;
				}
			}
		}
		close(PILEUP);
		print "\n";

		my %output;
		print "Processing variations\n";
		foreach my $key (keys %variation) {
			next unless (exists($variation{$key}{start}));
			my ($id, $rel_position) = split("\t",$key);
			my $chromosome;
			if ($id =~ /NC_0000(.{2})/x ) {
				$chromosome = $1;
			} elsif ($id =~ /chr(.*)$/x) {
				$chromosome = $1;
			}
			my $coord_id = $id;
			if ($id =~ /\( \s* CCDS/) {
				$coord_id =~ s/\( \s* CCDS.*$//;
			} elsif($id =~ /CCDS/ ) {
				$coord_id =~ s/\|.*$//;
			}
			my ($c_chromosome, $position, $offset, $c_orient) =
				$genomic_coords->Translate($coord_id,$rel_position);
			$chromosome ||= $c_chromosome;

			# left pad with zero so sorting is easy
			if ($chromosome =~ /^ \d+ $/x ) {
				$chromosome = sprintf "%02d", $chromosome;
			}
			$output{$chromosome}{$position}{id} = $id;

			foreach my $valuekey (keys %{$variation{$key}}) {
				if ($valuekey eq 'start' || $valuekey eq 'end') {
					$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey}+$offset;
				} else {
					$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey};
				}
			}
			delete $variation{$key};
		}
		undef %variation;
		my $fh;
		unless ($self->db) {
			print "Writing genotype submission file\n";
			$fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
			unless (defined($fh)) {
				$self->error_message("Unable to open genotype submission file for writing: $basename");
				return;
			}
		} else {
			print "Loading read groups\n";
		}
		my $mutation;
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
				my $quality_score = $output{$chr}{$pos}{quality_score};
				my $depth = $output{$chr}{$pos}{depth};
				my $software = 'maq' . $version;
				my $plus_minus = '+';
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
				if (defined($depth)) {
					push @scores, ("depth=$depth");
				}
				
				unless ($self->db) {
					Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build, $chromosome, $plus_minus, $start, $end,
																																	 $sample_id, $genotype_allele1, $genotype_allele2, \@scores, $number++);
				} else {
					MG::IO::GenotypeSubmission::AddMutation($mutation,$software,$build, $chromosome, $plus_minus, $start, $end,
																									$sample_id, $genotype_allele1, $genotype_allele2, \@scores, $number++);
				}
			}
		}
		unless ($self->db) {
			$fh->close();
		} else {
			MG::IO::GenotypeSubmission::Load($mutation,
																			 tech_type => '',
																			 mapping_reference => ''
																			);
		}
		return 1;
	}

# 'maq indelsoa $refbfa $mapfile |'
# CCDS15.1|Hs36.2|chr1    348825  -1      1       1       1       0.664983
# CCDS15.1|Hs36.2|chr1    378574  -5      0       1       1       1.329967
# CCDS15.1|Hs36.2|chr1    383826  5       1       1       1       0.664983

1;

