package Genome::Model::Command::Update::Reads::Solexa::Calibrate;

# This is mostly taken from the old prbcalib.pl script

use strict;
use warnings;

use UR;
use Command;
use File::Path;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'indir'   => { type => 'String',  doc => "existing prb (Bustard) directory"},
        'outdir'   => { type => 'String', doc => "new prb directory" },
        'gc'   => { type => 'Float',      doc => "the gc content percentage--0.408 is the default for homo sapiens", is_optional => 1 },
        'lanes'   => { type => 'String',  doc => "the lanes to process--the default is all: 12345678", is_optional => 1 },
        'chastity'   => { type => 'Integer',      doc => "the chastity value--6 is 0.6 and is the default", is_optional => 1 },
        'minbases'   => { type => 'Integer',      doc => "the number of bases to check for quality of reads.  the default is 12", is_optional => 1 },
        'start'   => { type => 'Integer',      doc => "the base position (zero offset) to start calibrating", is_optional => 1 },
        'onlycalculate'   => { type => 'Boolean',      doc => "only produce the prb calibration file", is_optional => 1 }
    ], 
);

sub help_brief {
    "creates calibrated prb files (with symbolic links to the original seq files)"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
creates calibrated prb files (with symbolic links to the original seq files)
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
		my($prbdir, $outdir, $chastity, $onlycalculate,
			 $min_bases, $gc_percent, $lanes, $start_base) =
				 ($self->indir, $self->outdir, $self->chastity, $self->onlycalculate,
					$self->minbases, $self->gc, $self->lanes, $self->start);
		$chastity ||= 6;
		$min_bases ||= 12;
		$gc_percent ||= 0.408;				# 40.8% GC content
		$lanes ||= '12345678';
		$start_base ||= -1;
		return unless ( defined($prbdir) && defined($outdir)
									);

		my @base_bias = ( 0, 0, 0, 0 );

		$prbdir =~ s/ \/ $ //x;					# Remove any trailing slash
		
		$chastity /= 10;
		
		# Get the prb file names
		my @prbfiles = glob($prbdir . '/s_[' . $lanes . ']*prb.txt*');
		
		# Make sure the output directory exists
		unless (-e $outdir) {
			mkpath $outdir;
		}

		my $calib_file = $outdir . '/prbcalib.csv';
		my ($calibration, $maxprb, $read_length);
		if (-r $calib_file) {
			($calibration, $maxprb, $read_length) = $self->ReadCalibration($calib_file);
		} else {
			($calibration, $maxprb, $read_length) =
				$self->CalculateCalibration(\@prbfiles, $outdir, $chastity, $calib_file,
																		$min_bases, $gc_percent, $start_base);
		}
		unless ($onlycalculate) {
			$self->RecalibratePRB(\@prbfiles, $outdir, $calibration, $chastity,
														$maxprb, $read_length, $min_bases);
		}
    return 1;
}

sub GetMaxPRB {
	my ($self,$prbfile) = @_;
	my ($maxprb) = -100;
	my $position_index = 0;
	my $max_position_index;
	
	if ($prbfile =~ /\.bz2$/x ) {
		unless (open(PRB,"bzcat $prbfile |")) {
			$self->error_message("Unable to bzcat prb file: $prbfile");
			exit 2;
		}
	} else {
		unless (open(PRB,"$prbfile")) {
			$self->error_message("Unable to open prb file: $prbfile");
			exit 2;
		}
	}
  while(<PRB>) {
    chomp;
    my @position = split("\t");
		$position_index = 0;
    foreach my $position (@position) {
      my $largest_prb = abs((sort { abs($a) <=> abs($b) }
														 split(' ',$position))[-1]);
			$maxprb = ($largest_prb > $maxprb) ? $largest_prb : $maxprb;
			$position_index++;
		}
		$max_position_index = $position_index;
	}
	close(PRB);
	return ($maxprb, $max_position_index);
}

sub IsGoodRead {
	my ($self,$line, $chastity, $maxprb, $min_bases) = @_;
	my $position_index = 0;
	foreach my $position (split("\t",$line)) {
		my @prb = split(' ',$position);
		# Chastity filter from Solexa (to filter mixed template reads)
		my @sort_prb = sort { $a <=> $b } @prb;
		my $chastity_value = ($sort_prb[-1] -	(($sort_prb[-2] + $sort_prb[-3])/2))/(2 * $maxprb);
		if ($chastity_value < $chastity) {
			return 0;
		}

		$position_index++;
		if ($position_index > $min_bases) {
			return 1;
		}
	}
	return 1;
}

sub CalculateCalibration {
	my ($self,$arrref_prbfiles, $outdir, $chastity, $calib_file,
			$min_bases, $gc_percent, $start_base) = @_;
	my (@prbfiles) = @{$arrref_prbfiles};
	my ($maxprb, $read_length) = $self->GetMaxPRB($prbfiles[0]);

	my @offset;
	my @avg;
	my @max;
	my @maxn;
	my @max_avg;
	my @max_avgn;
	my @min;
	my @minn;
	my @min_avg;
	my @min_avgn;
	my $max_threshold = int($maxprb/2);
	my $min_threshold = -1 * int($maxprb/2);
	my $all_read_count = 0;
	my $read_count = 0;
	foreach my $prbfile (@prbfiles) {
		if ($prbfile =~ /\.bz2$/x ) {
			unless (open(PRB,"bzcat $prbfile |")) {
				$self->error_message("Unable to bzcat prb file: $prbfile");
				exit 3;
			}
		} else {
			unless (open(PRB,"$prbfile")) {
				$self->error_message("Unable to open prb file: $prbfile");
				exit 3;
			}
		}
		print "Calibrating with: $prbfile\n";
		while(<PRB>) {
			chomp;
			$all_read_count++;
			next unless $self->IsGoodRead($_,$chastity,$maxprb,$min_bases);
			$read_count++;
			my $position_index = 0;
			foreach my $position (split("\t")) {
				my $base_index = 0;
				foreach my $prb (split(' ',$position)) {
					# Total r_{X i}
					$offset[$base_index][$position_index] += $prb;
					# Total r_i
					$avg[$position_index] += $prb;

					if ($prb >= $max_threshold) {
						# Total m_{X i}
						$max[$base_index][$position_index] += $prb;
						$maxn[$base_index][$position_index] += 1;
						# Total m_i
						$max_avg[$position_index] += $prb;
						$max_avgn[$position_index] += 1;
					} elsif ($prb <= $min_threshold) {
						# Total n_{X i}
						$min[$base_index][$position_index] += $prb;
						$minn[$base_index][$position_index] += 1;
						# Total n_i
						$min_avg[$position_index] += $prb;
						$min_avgn[$position_index] += 1;
					}
					$base_index++;
				}
				$position_index++;
			}
		}
		close(PRB);
	}

	unless ($read_count) {
		$self->error_message("No reads are good enough!");
		exit 4;
	}
	my $percent_used = sprintf "%.4f", (100 * $read_count/$all_read_count);
	unless (open (CALIB,">$calib_file")) {
		$self->error_message("Unable to open output file: $calib_file");
		exit 5;
	}

	print CALIB "maxprb\tread_length\tread_count\tall_read_count\tpercent_used\n";
	print CALIB "$maxprb\t$read_length\t$read_count\t$all_read_count\t$percent_used\n";

	my @bases = ( 'A', 'C', 'G', 'T' );
	# Weighting factors are 1.0 if an equal distribution
	my @weighting = (
									 (2 * (1 - $gc_percent)),	# A weighting factor
									 (2 * $gc_percent),	      # C weighting factor
									 (2 * $gc_percent),	      # G weighting factor
									 (2 * (1 - $gc_percent)) 	# T weighting factor
									);
	my @scale_plus;
	my @scale_minus;
	for (my $position_i = 0; $position_i < $read_length;$position_i++) {
		my $max_avg_n_i = (defined($max_avgn[$position_i]) &&
											 $max_avgn[$position_i] != 0) ?
												 $max_avgn[$position_i] : 1;
		# \bar{m}_{i}
	  $max_avg[$position_i] /= $max_avg_n_i;
		my $min_avg_n_i = (defined($min_avgn[$position_i]) && 
											 $min_avgn[$position_i] != 0) ?
												 $min_avgn[$position_i] : 1;
		# \bar{n}_{i}
	  $min_avg[$position_i] /= $min_avg_n_i;
		my $mean_r_i = $avg[$position_i]/($read_count * 4);
		for (my $base_i = 0; $base_i < 4;$base_i++) {
			# mean r_{X i}
			$offset[$base_i][$position_i] /= $read_count;
			# c_{X i} = mean_r_i - weighting_X * mean_r_{X i}
			$offset[$base_i][$position_i] = sprintf "%.8f",
				$mean_r_i - ($weighting[$base_i] * $offset[$base_i][$position_i]);

			my $max_n_i = (defined($maxn[$base_i][$position_i]) && 
										 $maxn[$base_i][$position_i] != 0) ?
											 $maxn[$base_i][$position_i] : 1;
			# \bar{m}_{X i}
			$max[$base_i][$position_i] /= $max_n_i;
			my $min_n_i = (defined($minn[$base_i][$position_i]) && 
										 $minn[$base_i][$position_i] != 0) ?
											 $minn[$base_i][$position_i] : 1;
			# \bar{n}_{X i}
			$min[$base_i][$position_i] /= $min_n_i;

			# {r_{max}}_{X i} = ( \bar{m}_{X i} - \bar{m}_{i} ) + r_{max}
			$max[$base_i][$position_i] =
				( $max[$base_i][$position_i] - $max_avg[$position_i] ) + $maxprb;

			# {r_{min}}_{X i} = ( \bar{n}_{X i} - \bar{n}_{i} ) + r_{min}.
			# - {r_{min}}_{X i} = ( \bar{n}_{i} - \bar{n}_{X i} ) + r_{max}.
			$min[$base_i][$position_i] =
				( $min_avg[$position_i] - $min[$base_i][$position_i] ) + $maxprb;

			# {S_{+}}_{X i} = (Q_{max} - c_{X i}) / {r_{max}}_{X i}
			$scale_plus[$base_i][$position_i] = sprintf "%.8f",
				( ($maxprb - $offset[$base_i][$position_i]) / 
					$max[$base_i][$position_i] );

			# {S_{-}}_{X i} = (Q_{max} + c_{X i}) / - {r_{min}}_{X i}.
			$scale_minus[$base_i][$position_i] = sprintf "%.8f",
				( ($maxprb + $offset[$base_i][$position_i]) / 
					$min[$base_i][$position_i] );
			if ($position_i <= $start_base) {
				$offset[$base_i][$position_i] = '0.0';
				$scale_plus[$base_i][$position_i] = '1.0';
				$scale_minus[$base_i][$position_i] = '1.0';
			}
		}
	}

	my %calibration;
	for(my $i=0;$i < 4;$i++) {
		print CALIB $bases[$i] . "\t" . join("\t",@{$offset[$i]}) . "\n";
		$calibration{offset}[$i] = $offset[$i];
		print CALIB $bases[$i] . "\t" . join("\t",@{$scale_plus[$i]}) . "\n";
		$calibration{scale_plus}[$i] = $scale_plus[$i];
		print CALIB $bases[$i] . "\t" . join("\t",@{$scale_minus[$i]}) . "\n";
		$calibration{scale_minus}[$i] = $scale_minus[$i];
	}
	close(CALIB);

	return (\%calibration, $maxprb, $read_length);
}

sub ReadCalibration {
	my ($self,$calib_file) = @_;

	unless (open(CALIB,"$calib_file")) {
		$self->error_message("Unable to open calibration file: $calib_file");
		exit 6;
	}
	my $line = <CALIB>;						# Header
	$line = <CALIB>;
	chomp $line;
	my ($maxprb, $read_length, $read_count) = split("\t",$line);
  my %calibration;
	my @split_line;
	for(my $i=0;$i < 4;$i++) {
		$line = <CALIB>;
		chomp $line;
		@split_line = split("\t",$line);
		shift @split_line;					# Pop off base
		$calibration{offset}[$i] = \@split_line;

		$line = <CALIB>;
		chomp $line;
		@split_line = split("\t",$line);
		shift @split_line;					# Pop off base
		$calibration{scale_plus}[$i] = \@split_line;

		$line = <CALIB>;
		chomp $line;
		@split_line = split("\t",$line);
		shift @split_line;					# Pop off base
		$calibration{scale_minus}[$i] = \@split_line;
	}
	close(CALIB);
	
	return (\%calibration, $maxprb, $read_length);
}

sub RecalibratePRB {
	my ($self,$arrref_prbfiles, $outdir, $calibration_ref, $chastity,
			$maxprb, $read_length, $min_bases) = @_;
	my (@prbfiles) = @{$arrref_prbfiles};
	my %calibration = %{$calibration_ref};
	my $read_count = 0;
	my $minprb = -1 * $maxprb;
	foreach my $prbfile (@prbfiles) {
		my $outprb_file = $outdir . '/' . basename($prbfile);
		if ($prbfile =~ /\.bz2$/x ) {
			unless (open(PRB,"bzcat $prbfile |")) {
				$self->error_message("Unable to bzcat prb file: $prbfile");
				exit 7;
			}
		} else {
			unless (open(PRB,"$prbfile")) {
				$self->error_message("Unable to open prb file: $prbfile");
				exit 7;
			}
		}
		my $seqfile = $prbfile;
		$seqfile =~ s/_prb/_seq/x;
		unless (-e $seqfile) {
			$seqfile =~ s/\.bz2//x;
		}
		if (-e $seqfile) {
			unless ($seqfile =~ /^ \/ /x) {
				$seqfile = '../' . $seqfile;
			}
			my $out_seqfile = $outprb_file;
			$out_seqfile =~ s/_prb/_seq/x;
			unless ($seqfile =~ /\.bz2/x) {
				$out_seqfile =~ s/\.bz2//x;
			}
			system("ln -s $seqfile $out_seqfile");
		}
		$outprb_file =~ s/\.bz2//x;
		unless (open(OUTPRB,">$outprb_file")) {
			$self->error_message("Unable to open output prb file: $outprb_file");
			exit 8;
		}
		print "Recalibrating: $prbfile to $outprb_file\n";
		
		while(<PRB>) {
			chomp;
# FOR DEBUGGING ONLY: Uncomment the next line if you want to see only the reads
# that were used to calculate the calibration.
#			next unless IsGoodRead($_,$chastity,$maxprb,$min_bases);
			$read_count++;
			my $position_index = 0;
			my @read = ();
			foreach my $position (split("\t")) {
				my @prbs = split(' ',$position);
				
				for (my $base_index = 0;$base_index < 4;$base_index++) {
					# Q_{X i} = S_plus_minus_{X i} r_plus_minus_{X i} + c_{X i}.
					my @offset = @{$calibration{offset}[$base_index]};
					my @scale = ($prbs[$base_index] >= 0) ?
						@{$calibration{scale_plus}[$base_index]} :
							@{$calibration{scale_minus}[$base_index]};
					$prbs[$base_index] = sprintf "%.0f",
						(($scale[$position_index] * $prbs[$base_index])
							+ $offset[$position_index]);
				}
				push @read, (join(' ',@prbs));
				$position_index++;
			}
			print OUTPRB join("\t",@read) . "\n";
		}
		close(OUTPRB);
		close(PRB);
	}
}

1;


