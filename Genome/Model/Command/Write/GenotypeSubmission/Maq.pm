package Genome::Model::Command::Write::GenotypeSubmission::Maq;

use strict;
use warnings;

use UR;
use Command;
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;
use File::Temp;

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
        'offset'   => { type => 'String',  doc => "coordinate offset to apply--default is zero", is_optional => 1},
        'record'   => { type => 'Boolean',  doc => "load a record at a time--default is all", is_optional => 1},
        'indel'   => { type => 'Boolean',  doc => "try to get indel's also (not implemented yet)", is_optional => 1},
        'version'   => { type => 'String',  doc => "maq software version--default is ''", is_optional => 1},
        'qcutoff'   => { type => 'String',  doc => "only process if quality score is greater than this value--default value is 0", is_optional => 1},
        'build'   => { type => 'String',  doc => "reference build version--default is 36", is_optional => 1},
        'loaddb'   => { type => 'Boolean',  doc => "load to the database--default is to produce a file", is_optional => 1},
        'check'   => { type => 'Boolean',  doc => "processing check only the input file", is_optional => 1},
        'rccheck'   => { type => 'Boolean',  doc => "revcomp check against the consensus--set check", is_optional => 1},
        'verbose'   => { type => 'Boolean',  doc => "print progress messages", is_optional => 1},
        'source'   => { type => 'String',  doc => "set source--default is 'wugsc'", is_optional => 1},
        'techtype'   => { type => 'String',  doc => "set tech_type--default is 'solexa'", is_optional => 1},
        'mappingreference'   => { type => 'String',  doc => "set mapping_reference--default is 'hg'", is_optional => 1},
        'runidentifier'   => { type => 'String',  doc => "set run_identifier--default is null", is_optional => 1}
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


my %IUBcode=(
	     A=>'AA',
	     C=>'CC',
	     G=>'GG',
	     T=>'TT',
	     M=>'AC',
	     K=>'GT',
	     Y=>'CT',
	     R=>'AG',
	     W=>'AT',
	     S=>'GC',
	     D=>'AGT',
	     B=>'CGT',
	     H=>'ACT',
	     V=>'ACG',
	     N=>'ACGT',
	    );

sub execute {
    my $self = shift;
		
    my($mapfile, $cnsfile, $refbfa, $sample, $basename, $coord_file,
       $indel, $version, $build, $qcutoff, $coord_offset, $record) =
				 ($self->mapfile, $self->cnsfile, $self->refbfa, $self->sample, $self->basename,
					$self->coordinates, $self->indel, $self->version, $self->build, $self->qcutoff, $self->offset, $self->record);
    return unless ( defined($mapfile) && defined($cnsfile) && defined($refbfa) &&
										defined($sample) && defined($basename)
									);
		$record ||= 0;
    $version ||= '';
    $build ||= '36';
    $qcutoff ||= 0;
    $coord_offset ||= 0;
		
    $| = 1;			# autoflush stdout

		my ($check, $rccheck, $verbose, $source, $techtype, $mappingreference, $runidentifier) =
			($self->check, $self->rccheck, $self->verbose, $self->source,
			 $self->techtype, $self->mappingreference, $self->runidentifier);
		$check ||= 0;
		$rccheck ||= 0;
		$techtype ||= 'solexa';
		$mappingreference ||= 'hg';
		
    my $genomic_coords = MG::Transform::Coordinates::TranscriptToGenomic->new(
																																							coordinate_file => $coord_file);
		
    my $snp_cmd = "maq cns2snp $cnsfile |";
    unless (open(SNP,$snp_cmd)) {
			$self->error_message("Unable to run input command: $snp_cmd");
			return;
    }
    my %variation;
		if ($verbose) {
			if ($record) {
				print "Record based processing $cnsfile for SNPs\n";
			} else {
				print "Processing $cnsfile for SNPs\n";
			}
		}
		my $tmp_pos_list_fh = File::Temp->new(DIR => $ENV{TMP});
    while(<SNP>) {
			chomp;
			my ($id, $start, $ref_sequence, $iub_sequence, $quality_score, $depth, $avg_hits, $high_quality, $unknown) = split("\t");
			next if ($quality_score < $qcutoff );
			my $key = "$id\t$start";
			print $tmp_pos_list_fh "$id\t$start\n";
			my $genotype = $IUBcode{$iub_sequence};
			my $cns_sequence = substr($genotype,0,1);
			my $var_sequence = (length($genotype) > 2) ? 'X' : substr($genotype,1,1);
			if ($ref_sequence eq $cns_sequence &&
					$ref_sequence eq $var_sequence) {
				next;										# no variation
			}
			$variation{$key}{start} = $start;
			$variation{$key}{end} = $start;
			$variation{$key}{ref_sequence} = $ref_sequence;
			$variation{$key}{var_sequence} = $var_sequence;
			if ($var_sequence eq $cns_sequence) {
				# homozygous rare
				$variation{$key}{cns_sequence} = $cns_sequence;
			} elsif ($ref_sequence ne $cns_sequence) {
				if ($ref_sequence eq $var_sequence) {
					$variation{$key}{var_sequence} = $cns_sequence;
				} else {
					$variation{$key}{cns_sequence} = $cns_sequence;
				}
			}
			$variation{$key}{quality_score} = $quality_score;
			$variation{$key}{total_reads} = $depth;
			$variation{$key}{avg_hits} = $avg_hits;
			$variation{$key}{high_quality} = $high_quality;
			$variation{$key}{unknown} = $unknown;
    }
    close(SNP);

		my $tmp_pos_list = $tmp_pos_list_fh->filename();
		$tmp_pos_list_fh->close();

		my $pileup_cmd = "maq pileup -v -l $tmp_pos_list $refbfa $mapfile |";
    unless (open(PILEUP,$pileup_cmd)) {
			$self->error_message("Unable to run input command: $pileup_cmd");
			return;
    }
    my $count = 0;
		if ($verbose) {
			print "Processing $mapfile for pileup ";
		}
    while(<PILEUP>) {
			chomp;
			my ($id, $position, $ref_base, $depth, $bases) = split("\t");
			if ($depth > 0) {
				my $key = "$id\t$position";
				if	(defined($variation{$key})) {
					if ($verbose) {
						print '.' if (++$count % 1000 == 0);
					}
					$variation{$key}{depth} = $depth;
					my $bases_length = length($bases);
					my $temp_bases = $bases;
					$temp_bases =~ s/[\,\.]//gx;
					$variation{$key}{reference_reads} = $bases_length - length($temp_bases);
					if ($bases =~ /A/ix ){
						$temp_bases = $bases;
						$temp_bases =~ s/A//gix;
						$variation{$key}{variant_reads}{A} = $bases_length - length($temp_bases);
					}
					if ($bases =~ /C/ix ){
						$temp_bases = $bases;
						$temp_bases =~ s/C//gix;
						$variation{$key}{variant_reads}{C} = $bases_length - length($temp_bases);
					}
					if ($bases =~ /G/ix ){
						$temp_bases = $bases;
						$temp_bases =~ s/G//gix;
						$variation{$key}{variant_reads}{G} = $bases_length - length($temp_bases);
					}
					if ($bases =~ /T/ix ){
						$temp_bases = $bases;
						$temp_bases =~ s/T//gix;
						$variation{$key}{variant_reads}{T} = $bases_length - length($temp_bases);
					}
					
					#		$variation{$key}{ref_base} = $ref_base;
					#		$variation{$key}{bases} = $bases;
				}
			}
    }
    close(PILEUP);
		if ($verbose) {
			print "\n";
		}
    
    my %output;
		if ($verbose) {
			print "Processing variations\n";
		}
    my %bad_ids = ();
    foreach my $key (keys %variation) {
			next unless (exists($variation{$key}{start}));
			my ($id, $rel_position) = split("\t",$key);
			my $chromosome;
			if ($id =~ /NC_0000(.{2})/x ) {
				$chromosome = $1;
			} elsif ($id =~ /chr(.*)$/x) {
				$chromosome = $1;
			} elsif ($id =~ /^ \d+ $/x || $id =~ /^ [XY] $/x) {
				$chromosome = $id;
			}
			my $coord_id = $id;
			if ($id =~ /\( \s* CCDS/) {
				$coord_id =~ s/\( \s* CCDS.*$//;
			} elsif($id =~ /CCDS/ ) {
				$coord_id =~ s/\|.*$//;
			}
			my ($c_chromosome, $position, $offset, $c_orient) =
				$genomic_coords->Translate($coord_id,$rel_position);
			$position += $coord_offset; # add a user supplied offset--the position is still undef  if undef
			$rel_position += $coord_offset; # add a user supplied offset--the rel_position is still undef  if undef
			$offset += $coord_offset; # add a user supplied offset--the offset is still undef  if undef
			if (defined($c_chromosome) && defined($rel_position)) {
				if ($c_chromosome =~ /^ \d+ $/x ) {
					$c_chromosome = sprintf "%02d", $c_chromosome;
				}
				$chromosome ||= $c_chromosome;
				$position ||= $rel_position;
				$output{$chromosome}{$position}{orientation} = $c_orient;
			}
			
			unless (defined($chromosome)) {
				$bad_ids{$id} = 1;
				next;
			}
			
			# left pad with zero so sorting is easy
			if ($chromosome =~ /^ \d+ $/x ) {
				$chromosome = sprintf "%02d", $chromosome;
			}
			$output{$chromosome}{$position}{id} = $id;
			
			foreach my $valuekey (keys %{$variation{$key}}) {
				if ($valuekey eq 'start' || $valuekey eq 'end') {
					$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey}+$offset;
				} elsif (exists($variation{$key}{$valuekey})) {
					$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey};
				}
			}
			delete $variation{$key};
    }
    my $bad_ids = join(' ',keys %bad_ids);
    if ($bad_ids ne '') {
			print "Could not find coordinate translation for ids: $bad_ids\n";
    }
    undef %variation;
    my $fh;
		if ($verbose) {
			if ($record) {
				print "Writing genotype submission file and loading database\n";
			} else {
				print "Writing genotype submission file\n";
			}
		}
		$fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
		unless (defined($fh)) {
			$self->error_message("Unable to open genotype submission file for writing: $basename");
			return;
		}
    my $sample_temp = $sample;
    $sample_temp =~ s/454_EST_S_//x;
    my ($sample_a, $sample_b) = split('-',$sample_temp);
    $sample_b = sprintf "%05d",$sample_b;
    my $sample_id = $sample_a . '-' . $sample_b;
		my $mutation = {};
    my $number = 1;
    foreach my $chr (sort (keys %output)) {
			my $chromosome = $chr;
			$chromosome =~ s/^0//;
			foreach my $pos (sort { $a <=> $b } (keys %{$output{$chr}})) {
				my $start = $output{$chr}{$pos}{start};
				my $end = $output{$chr}{$pos}{end};
				my $ref_sequence = $output{$chr}{$pos}{ref_sequence};
				my $var_sequence = $output{$chr}{$pos}{var_sequence};
				unless (defined($ref_sequence) && defined($var_sequence)) {
					next;
				}
				my $cns_sequence = $output{$chr}{$pos}{cns_sequence};
				my $total_reads = $output{$chr}{$pos}{total_reads};
				my $variant_reads;
				if (exists($output{$chr}{$pos}{variant_reads}{$var_sequence})) {
					$variant_reads = $output{$chr}{$pos}{variant_reads}{$var_sequence};
				}
				my $depth = $output{$chr}{$pos}{depth};
				my $ref_reads = $output{$chr}{$pos}{reference_reads};
				if (defined($cns_sequence) && $cns_sequence ne '') {
					if (exists($output{$chr}{$pos}{variant_reads}{$cns_sequence})) {
						$ref_reads = $output{$chr}{$pos}{variant_reads}{$cns_sequence};
					}
				} else {
					if (exists($output{$chr}{$pos}{variant_reads}{$ref_sequence})) {
						$ref_reads = $output{$chr}{$pos}{variant_reads}{$ref_sequence};
					}
				}
				my $quality_score = $output{$chr}{$pos}{quality_score};
				my $software = 'maq' . $version;
				my $plus_minus = (defined($output{$chr}{$pos}{orientation})) ? $output{$chr}{$pos}{orientation} : '+';
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
				if (defined($cns_sequence)) {
					push @scores, ("cns=$cns_sequence");
				}
				
				Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build, $chromosome, $plus_minus, $start, $end,
																																 $sample_id, $genotype_allele1, $genotype_allele2, \@scores, $number);
				if ($self->loaddb) {
					$mutation = MG::IO::GenotypeSubmission::AddMutation($mutation,$software,$build,
																															$chromosome, $plus_minus,
																															"$start", "$end",
																															$sample_id, 
																															$genotype_allele1, $genotype_allele2,
																															\@scores, $number);
					if ($record) {
						MG::IO::GenotypeSubmission::LoadDatabase($mutation,
																										 check => $check,
																										 rccheck => $rccheck,
																										 verbose => $verbose,
																										 source => $source,
																										 tech_type => $techtype,
																										 mapping_reference => $mappingreference,
																										 run_identifier => $runidentifier
																										);
					}
				}
			  if ($record) {
					$mutation = {};
				}
				$number += 1;
			}
    }
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
    
# 'maq indelsoa $refbfa $mapfile |'
# CCDS15.1|Hs36.2|chr1    348825  -1      1       1       1       0.664983
# CCDS15.1|Hs36.2|chr1    378574  -5      0       1       1       1.329967
# CCDS15.1|Hs36.2|chr1    383826  5       1       1       1       0.664983

1;

