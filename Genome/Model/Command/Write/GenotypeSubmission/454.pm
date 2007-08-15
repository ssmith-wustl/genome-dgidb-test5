package Genome::Model::Command::Write::GenotypeSubmission::454;

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
        'dir'   => { type => 'String',  doc => "project alignment (input) directory"},
        'basename'   => { type => 'String',  doc => "output genotype submission file prefix basename"}
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

sub execute {
    my $self = shift;

		my($dir, $sample, $basename) = 
				 ($self->dir, $self->sample, $self->basename);
		return unless ( defined($dir) && defined($sample) && defined($basename)
									);

		$dir =~ s/ \/ $ //x;				# Remove any trailing slash

#		my $diff_file = "$dir/454AllDiffs.txt";
		my $diff_file = "$dir/454HCDiffs.txt";
		unless (open(DIFF,$diff_file)) {
			$self->error_message("Unable to open input file: $diff_file");
			return;
		}
		my %variation;
		print "Processing $diff_file\n";
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
		print "Processing $aligninfo_file\n";
		my $header = <ALIGN>;
		my ($id, $position);
		while(<ALIGN>) {
			chomp;
			s/ //g;									# remove spaces (keep tabs)
			if (/^ \s* > /x ) {
				($id, $position) = split("\t");
				$id =~ s/\s*$//x;
				$id =~ s/^ \s* > \s*//x;
			} else {
				my ($position, $reference, $consensus, $quality_score, $depth, $signal, $stddeviation) = split("\t");
				my $key = "$id\t$position";
				if (exists($variation{$key}{start})) {
					if ($variation{$key}{ref_sequence} eq $reference) {
#						$variation{$key}{reference} = $reference;
#						$variation{$key}{consensus} = $consensus;
						$variation{$key}{quality_score} = $quality_score;
						$variation{$key}{depth} = $depth;
						$variation{$key}{signal} = $signal;
						$variation{$key}{signal_sd} = $stddeviation;
					}
				}
			}
		}
		close(ALIGN);

		my %output;
		print "Processing variations\n";
		foreach my $key (keys %variation) {
			next unless (exists($variation{$key}{start}));
			my ($id, $position) = split("\t",$key);
			my $chromosome;
			if ($id =~ /NC_0000(.{2})/x ) {
				$chromosome = $1;
			} elsif ($id =~ /chr(.*)$/x) {
				$chromosome = $1;
			}
			# left pad with zero so sorting is easy
			if ($chromosome =~ /^ \d+ $/x ) {
				$chromosome = sprintf "%02d", $chromosome;
			}
			foreach my $valuekey (keys %{$variation{$key}}) {
				$output{$chromosome}{$position}{$valuekey} = $variation{$key}{$valuekey};
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
				my $ref_reads = $total_reads - $variant_reads;
#				my $reference = $output{$chr}{$pos}{reference};
#				my $consensus = $output{$chr}{$pos}{consensus};
				my $quality_score = $output{$chr}{$pos}{quality_score};
				my $depth = $output{$chr}{$pos}{depth};
				my $signal = $output{$chr}{$pos}{signal};
				my $signal_sd = $output{$chr}{$pos}{signal_sd};
				my $software = 'runMapping';
				my $build_id = 'B36';
				my $plus_minus = '+';
				my $genotype_allele1 = substr($ref_sequence,0,1);
				my $genotype_allele2 = substr($var_sequence,0,1);
				$quality_score ||= '';
				$depth ||= '';
				$signal ||= '';
				$signal_sd ||= '';
				my @scores = ($quality_score,$ref_reads,$variant_reads,$depth,$signal,$signal_sd);

				Genome::Model::Command::Write::GenotypeSubmission::Write($fh,$software,$build_id, $chromosome, $plus_minus, $start, $end,
																																 $sample_id, $genotype_allele1, $genotype_allele2, \@scores);
			}
		}
		$fh->close();
    return 1;
}

1;

