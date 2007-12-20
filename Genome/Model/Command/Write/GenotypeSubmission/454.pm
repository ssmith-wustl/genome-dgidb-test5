package Genome::Model::Command::Write::GenotypeSubmission::454;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Path;
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "project alignment (input) directory"},
        'basename'   => { type => 'String',  doc => "output genotype submission file prefix basename"},
        'coordinates'   => { type => 'String',  doc => "coordinate translation file", is_optional => 1},
        'offset'   => { type => 'String',  doc => "coordinate offset to apply--default is zero", is_optional => 1},
        'all'   => { type => 'Boolean',  doc => "use the all instead of HC diffs file", is_optional => 1},
        'version'   => { type => 'String',  doc => "454 software version--default is 1.1", is_optional => 1},
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
genome-model write genotype-submission 454 --dir=454/ccds/alignment --sample=H_GW-454_EST_S_8977 --basename=username
EOS
}

sub help_brief {
    "create a genotype submission file from runMapping output"
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

sub MakeMatches {
	my ($id, $position, $sequence, $variation_ref) = @_;
	my $i = 0;
	my %matches;
	foreach my $allele (split('',$sequence)) {
		$matches{$id}{$position+$i++}{$allele} = $variation_ref;
	}
	return \%matches;
}

sub execute {
	my $self = shift;
	
	my($dir, $sample, $basename, $coord_file, $all, $version, $build, $coord_offset) = 
		($self->dir, $self->sample, $self->basename, $self->coordinates, $self->all,
		 $self->version, $self->build, $self->offset);
	return unless ( defined($dir) && defined($sample) && defined($basename)
								);
	$version ||= '1.1';
	$build ||= '36';
	$coord_offset ||= 0;
	
	$dir =~ s/ \/ $ //x;				# Remove any trailing slash
	
	$| = 1;											# autoflush stdout
	
	my ($check, $rccheck, $verbose, $source, $techtype, $mappingreference, $runidentifier) =
		($self->check, $self->rccheck, $self->verbose, $self->source,
		 $self->techtype, $self->mappingreference, $self->runidentifier);
	$check ||= 0;
	$rccheck ||= 0;
	$techtype ||= '454';
	$mappingreference ||= 'cdna_merged';

	my $genomic_coords = new MG::Transform::Coordinates::TranscriptToGenomic(
																																					 coordinate_file => $coord_file);
	
	my $diff_file = ($all) ? "$dir/454AllDiffs.txt" : "$dir/454HCDiffs.txt";
	unless (open(DIFF,$diff_file)) {
		$self->error_message("Unable to open input file: $diff_file");
		return;
	}
	my %variation;
	if ($verbose) {
		print "Processing $diff_file\n";
	}
	while(<DIFF>) {
		chomp;
		if (/^ \s* > /x ) {
	    s/ //g;									# remove spaces (keep tabs)
	    my ($id, $start, $end, $ref_sequence, $var_sequence, $freq_forward, $freq_reverse, $variant_reads, $total_reads, $variant_percent) = split("\t");
	    $id =~ s/\s*$//x;
	    $id =~ s/^ \s* > \s*//x;
	    my $key = "$id\t$start";
	    $variation{$key}{start} = $start;
	    $variation{$key}{end} = $end;
	    $variation{$key}{ref_sequence} = $ref_sequence;
	    $variation{$key}{var_sequence} = $var_sequence;
	    $variation{$key}{match} = MakeMatches($id,$start,$var_sequence,$variation{$key});
			#				$variation{$key}{freq_forward} = $freq_forward;
			#				$variation{$key}{freq_reverse} = $freq_reverse;
	    $variation{$key}{variant_reads} = $variant_reads;
	    $variation{$key}{total_reads} = $total_reads;
		}
	}
	close(DIFF);
	my $aligninfo_file = "$dir/454AlignmentInfo.tsv";
	unless (open(ALIGN,$aligninfo_file)) {
		$self->error_message("Unable to open input file: $aligninfo_file");
		return;
	}
	if ($verbose) {
		print "Processing $aligninfo_file ";
	}
	my $header = <ALIGN>;
	my ($id, $position);
	my $matches = {};
	my $count = 0;
	$id = '';
	while(<ALIGN>) {
		chomp;
		s/ //g;									# remove spaces (keep tabs)
		if ($verbose) {
			print '.' if (++$count % 100000 == 0);
		}
		if (/^ \s* > /x ) {
	    if (exists($matches->{$id})) {
				delete $matches->{$id};
	    }
	    ($id, $position) = split("\t");
	    $id =~ s/\s*$//x;
	    $id =~ s/^ \s* > \s*//x;
		} else {
	    my ($position, $reference, $consensus, $quality_score, $depth, $signal, $stddeviation) = split("\t");
	    my $key = "$id\t$position";
	    my $add_matches_ref = (exists($variation{$key}{match})) ?
				$variation{$key}{match} : {};
	    $matches = { %{$matches}, %{$add_matches_ref} };
	    
	    if (exists($matches->{$id}{$position}) &&
					exists($matches->{$id}{$position}{$consensus})
				 ) {
				my $variation_ref = $matches->{$id}{$position}{$consensus};
				if ($reference ne '-' && $reference ne $consensus) {
					$variation_ref->{cns_sequence} = $consensus;
				}
				unless ($consensus eq '-') {
					$variation_ref->{quality_score} += $quality_score;
					$variation_ref->{depth} += $depth;
					$variation_ref->{signal} += $signal;
					$variation_ref->{signal_sd} += $stddeviation;
					$variation_ref->{number} += 1;
				}
	    }
	    
	    my @match_positions = (sort { $a <=> $b } (keys %{$matches->{$id}}));
	    my $low_position = (defined($match_positions[0])) ? $match_positions[0] : $position;
	    for (my $i = $low_position;$i < $position;$i++) {
				if (exists($matches->{$id}{$i})) {
					delete $matches->{$id}{$i};
				}
	    }
		}
	}
	close(ALIGN);
	if ($verbose) {
		print "\n";
	}
	
	my %output;
	if ($verbose) {
		print "Processing variations\n";
	}
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
		
		# left pad with zero so sorting is easy
		if ($chromosome =~ /^ \d+ $/x ) {
	    $chromosome = sprintf "%02d", $chromosome;
		}
		$output{$chromosome}{$position}{id} = $id;
		
		my $number = $variation{$key}->{number};
		$number ||= 1;
		if (defined($variation{$key}->{quality_score})) {
	    $variation{$key}->{quality_score} = sprintf "%.0f",
				$variation{$key}->{quality_score} / $number;
		}
		if (defined($variation{$key}->{depth})) {
	    $variation{$key}->{depth} = sprintf "%.0f",
				$variation{$key}->{depth} / $number;
		}
		if (defined($variation{$key}->{signal})) {
	    $variation{$key}->{signal} = sprintf "%.2f",
				$variation{$key}->{signal} / $number;
		}
		if (defined($variation{$key}->{signal_sd})) {
	    $variation{$key}->{signal_sd} = sprintf "%.2f",
				$variation{$key}->{signal_sd} / $number;
		}
		foreach my $valuekey (keys %{$variation{$key}}) {
	    if ($valuekey eq 'start' || $valuekey eq 'end') {
				$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey}+$offset;
	    } else {
				$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey};
	    }
		}
	}
	undef %variation;
	my $fh;
	if ($verbose) {
		print "Writing genotype submission file\n";
	}
	$fh = Genome::Model::Command::Write::GenotypeSubmission::Open($basename);
	unless (defined($fh)) {
		$self->error_message("Unable to open genotype submission file for writing: $basename");
		return;
	}
	my $mutation = {};
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
	    #my $freq_forward = $output{$chr}{$pos}{freq_forward};
	    #my $freq_reverse = $output{$chr}{$pos}{freq_reverse};
	    my $variant_reads = $output{$chr}{$pos}{variant_reads};
	    my $total_reads = $output{$chr}{$pos}{total_reads};
	    my $ref_reads;
	    if (defined($total_reads) && defined($variant_reads)) {
				$ref_reads = $total_reads - $variant_reads;
	    }
	    my $quality_score = $output{$chr}{$pos}{quality_score};
	    my $depth = $output{$chr}{$pos}{depth};
	    my $signal = $output{$chr}{$pos}{signal};
	    my $signal_sd = $output{$chr}{$pos}{signal_sd};
	    my $software = 'runMapping' . $version;
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
	    if (defined($signal)) {
				push @scores, ("signal=$signal");
	    }
	    if (defined($signal_sd)) {
				push @scores, ("signal_sd=$signal_sd");
	    }
	    
			Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build, $chromosome, $plus_minus, $start, $end,
																															 $sample_id, $genotype_allele1, $genotype_allele2, \@scores, $number++);
	    if ($self->loaddb) {
				$mutation = MG::IO::GenotypeSubmission::AddMutation($mutation,$software,$build,
																														$chromosome, $plus_minus,
																														"$start", "$end",
																														$sample_id, 
																														$genotype_allele1, $genotype_allele2,
																														\@scores, $number);
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

1;

