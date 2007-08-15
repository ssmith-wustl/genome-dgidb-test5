package Genome::Model::Command::Update::Reads::Solexa::ToGerald;

# This is mostly taken from the old prbseq2sequence.pl script

use strict;
use warnings;

use UR;
use Command;
use IO::File;
use File::Path;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'prbdir'   => { type => 'String',  doc => "existing prb (Bustard) directory"},
        'seqdir'   => { type => 'String',  doc => "existing seq (Bustard) directory"},
        'outdir'   => { type => 'String', doc => "new output directory" },
        'lanes'   => { type => 'String',  doc => "the lanes to process--the default is all: 12345678", is_optional => 1 },
        'chastity'   => { type => 'Integer',      doc => "the chastity value--6 is 0.6 and is the default", is_optional => 1 },
        'minbases'   => { type => 'Integer',      doc => "the number of bases to check for quality of reads.  the default is 12", is_optional => 1 },
        'start'   => { type => 'Integer',      doc => "the base position (zero offset) to start calibrating", is_optional => 1 }
    ], 
);

sub help_brief {
    "produces sequence files from prb and old seq files"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
produces sequence files from prb and old seq files
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
		my($prbdir, $seqdir, $outdir, $chastity, $min_bases, $lanes, $start_base) =
				 ($self->prbdir, $self->seqdir, $self->outdir, $self->chastity,
					$self->minbases, $self->lanes, $self->start);
		$chastity ||= 6;
		$min_bases ||= 12;
		$lanes ||= '12345678';
		$start_base ||= -1;
		return unless ( defined($prbdir) && defined($seqdir) && defined($outdir)
									);

		$prbdir =~ s/ \/ $ //x;					# Remove any trailing slash
		$seqdir =~ s/ \/ $ //x;					# Remove any trailing slash

		$chastity /= 10;
		
		# Make sure the output directory exists
		unless (-e $outdir) {
			mkpath $outdir;
		}
		
		my @maxprbfiles = glob($prbdir . '/s_[' . $lanes . ']*prb.txt*');
		my ($maxprb, $read_length) = $self->GetMaxPRB($maxprbfiles[0]);
		@maxprbfiles = ();
		undef @maxprbfiles;
		
		foreach my $lane (split('',$lanes)) {
			# Get the prb file names
			my @prbfiles = glob($prbdir . '/s_' . $lane . '*prb.txt*');
			
			my $read_prefix = '';
			my $sequence_file = $outdir . '/' . 's_' . $lane . '_sequence.txt';
			my $sequence_fh = new IO::File;
			unless ($sequence_fh->open(">$sequence_file")) {
				$self->error_message("Unable to open create sequence file: $sequence_file");
				exit 1;
			}
			$self->ConvertSequence($maxprb,$read_length,$min_bases,$chastity,$start_base,
											$seqdir,$outdir,$read_prefix,\@prbfiles,$sequence_fh);
			$sequence_fh->close();
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

sub ConvertSequence {
	my ($self,$maxprb,$read_length,$min_bases,$chastity,$start_base,
			$seqdir,$outdir,$read_prefix,$arrref_prbfiles,$sequence_fh) = @_;
	my (@prbfiles) = @{$arrref_prbfiles};
	foreach my $prbfile (@prbfiles) {
		my $newseq_file = $outdir . '/' . basename($prbfile);
		$newseq_file =~ s/_prb/_seq/;
		$newseq_file =~ s/\.bz2//;
		my $seqfile = $seqdir . '/' . basename($prbfile);
		$seqfile =~ s/_prb/_seq/;
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
		unless (-e $seqfile) {
			$seqfile =~ s/\.bz2//;
		}
		if ($seqfile =~ /\.bz2$/x ) {
			unless (open(SEQ,"bzcat $seqfile |")) {
				$self->error_message("Unable to bzcat seq file: $seqfile");
				exit 2;
			}
		} else {
			unless (open(SEQ,"$seqfile")) {
				$self->error_message("Unable to open seq file: $seqfile");
				exit 2;
			}
		}
		unless (open(NEWSEQ,">$newseq_file")) {
			$self->error_message("Unable to create new seq file: $newseq_file");
			exit 4;
		}
		print "Converting: $prbfile $seqfile\n";
		my $all_read_count = 0;
		my $read_count = 0;
		while(<PRB>) {
			chomp;
			my $seq_line = <SEQ>;
			chomp $seq_line;
			my ($seq_lane,$seq_tile,$seq_x,$seq_y) = split("\t",$seq_line);
			my $seq_read_id;
			if ($read_prefix ne '') {
				$seq_read_id = join('_',
															 ($read_prefix,$seq_lane,$seq_tile,$seq_x,$seq_y)
															);
			} else {
				$seq_read_id = join('_',
															 ($seq_lane,$seq_tile,$seq_x,$seq_y)
															);
			}
			$all_read_count++;

			my ($sequence,$quality);
			my @basetrans = ( 'A', 'C', 'G', 'T' );
			foreach my $position (split("\t")) {
				my @base = split(' ',$position);
				my $maxscore = -100;
				my $maxbase = '';
				for(my $j=0;$j < 4;$j++) {
					if ($base[$j] > $maxscore) {
						$maxscore = $base[$j];
						$maxbase = $basetrans[$j];
					}
				}
				$sequence .= $maxbase;
				$quality .= chr($maxscore+64);
			}

			print NEWSEQ join("\t",($seq_lane,$seq_tile,$seq_x,$seq_y,$sequence))
				. "\n";
			next unless $self->IsGoodRead($_,$chastity,$maxprb,$min_bases);
			$read_count++;
			print $sequence_fh '@' . $seq_read_id . "\n";
			print $sequence_fh $sequence . "\n";
			print $sequence_fh '+' . $seq_read_id . "\n";
			print $sequence_fh $quality . "\n";
		}
		close(NEWSEQ);
		close(PRB);
		close(SEQ);
	}
}

1;


