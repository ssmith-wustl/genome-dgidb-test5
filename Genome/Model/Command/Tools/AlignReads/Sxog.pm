
# Rename the final word in the full class name to match the filename <---
package Genome::Model::Command::Tools::AlignReads::Sxog;

use strict;
use warnings;

use above "Genome";
use Command;

use GSC;
use IO::File;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',                       
    has => [                                # Specify the command's properties (parameters) <--- 
        'prbmap'   => { type => 'String',      doc => "prb map file name"},
        'dirs'   => { type => 'String',      doc => "colon delimited list of directories--default is: ./", is_optional => 1 },
        'files'   => { type => 'String',      doc => "file wildcard--default is: *.sxog*", is_optional => 1 },
        'chr_list'   => { type => 'String',      doc => "colon delimited list chromosomes--default is homo sapiens chromosomes plus random", is_optional => 1 },
        'output_base'   => { type => 'String',      doc => "prefix output file name base--default is sxog", is_optional => 1 },
        'chr_program'   => { type => 'String',      doc => "per chromosome backend program--default is sxog_chr in path", is_optional => 1 },
        'runid'   => { type => 'Integer',      doc => "run id (high part of the read identifier)--default is 1", is_optional => 1 },
        'startread'   => { type => 'Integer',      doc => "starting read number (low part of the read identifier)--default is 0", is_optional => 1 },
        'max_align'   => { type => 'Integer',      doc => "maximum number of alignments--default is 10000000", is_optional => 1 },
        'nobsub'   => { type => 'Boolean',      doc => "not recommended: force running without running under bsub", is_optional => 1 }
    ], 
);

sub help_brief {                            # Keep this to just a few words <---
    "parses SXOligoSearchG search results into binary alignment files"                 
}

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
bsub -oo sxog.out -q long -n 48 -R 'select[type==LINUX64] span[ptile=2]' genome-model align-reads sxog --chr-program=/gscmnt/sata114/info/medseq/pkg/bin64/sxog_chr --dirs=/gscmnt/sata114/info/medseq/projects/chimp5mb/samples/chimp5mb/genome-models/alignment/sxog/cal --prbmap=/gscmnt/sata114/info/medseq/projects/chimp5mb/samples/chimp5mb/runs/solexa/calprb.map
EOS
}

sub help_detail {                           # This is what the user will see with the longer version of help. <---
    return <<EOS 
Parses SXOligoSearchG search results into binary alignment files.

It is highly suggested to run this as:
    bsub -oo sxog.out -q long -n 48 -R 'select[type==LINUX64] span[ptile=2]' genome-model align-reads sxog ARGS
where 48 is the number of chromosomes (including random).

NOT RECOMMENDED: Use the option: --nobsub to run it without bsub.
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried.  Delete unless you use it. <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {                               # Replace with real execution logic.
    my $self = shift;

		return unless $self->prbmap;
		my($sxog_files_ref) = $self->FileList();
		my(@sxog_files) = @{$sxog_files_ref};

		my($sxog) = $self->InitSxog();

		foreach my $sxog_file (@sxog_files) {
			print "$sxog_file\n";
			$sxog->Process($sxog_file);
		}
		$sxog->Close();

    return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}

#-------------------------------------------------
sub FileList {
  my($self) = @_;
  my(@dirs) = split(":",$self->dirs);
  my($files) = $self->files;
	$files ||= '*.sxog*';
	if (defined($self->dirs)) {
		@dirs = map { $_ . '/' . $files } split(":",$self->dirs);
	} else {
		@dirs = ( './' . $files );
	}
  my(@filelist);

  foreach my $dir (@dirs) {
		my @files = glob($dir);
		push @filelist, @files;
	}
  @filelist = sort @filelist;
  return \@filelist;
}
#-------------------------------------------------

sub InitSxog {
 	my ($self) = @_;
	$self->{_prb_map} = $self->prbmap;
	$self->{_output_base} = (defined($self->output_base)) ?
													 $self->output_base : 'sxog';
	$self->{_chr_program} = (defined($self->chr_program)) ?
													 $self->chr_program : 'sxog_chr';
	$self->{_run_id} = (defined($self->runid)) ?
													 $self->runid : 1;
	$self->{_read_number} = (defined($self->startread)) ?
													 $self->startread : 0;
	$self->{_max_align} = (defined($self->max_align)) ?
													 $self->max_align : 10000000;
	my @chr_list;
	my @chrs;
	if (defined($self->chr_list)) {
		@chr_list = split(":",$self->chr_list);
		@chrs = @chr_list;
	} else {
		@chr_list = ( 0 .. 22, 'X', 'Y' ); # include a chromosome zero--for nonmatches
	  @chrs = map {($_, $_ . '_random')} @chr_list;
	}

	# Create (and truncate) the files here.
	$self->{'chromosomes'} = \@chrs;

#	$SIG{'CHLD'} = 'IGNORE';
#	$SIG{'PIPE'} = 'IGNORE';
	my $fh;
	my $run_id = $self->{_run_id};
	$self->{_output_base} .= "_${run_id}";
	my $output_base = $self->{_output_base};

	# Setup list of hosts by chromosome job
	my $total_lsbhosts = 0;
	my @lsbhosts;
	if (defined($ENV{LSB_HOSTS})) {
	  foreach my $lsbhost ( split(' ',$ENV{LSB_HOSTS}) ) {
	    if (!exists($self->{lsbhosts}{$lsbhost})) {
	      $self->{lsbhosts}{$lsbhost} = 1;
	      push @lsbhosts, ($lsbhost);
	      $total_lsbhosts++;
	    }
	  }
	}
	my $num_jobs = $#chr_list + 1;
	my $jobs_per_host = ($total_lsbhosts > 0 &&
			     $num_jobs > $total_lsbhosts) ?
			       int($num_jobs / $total_lsbhosts ) : 1;
	if ($total_lsbhosts) {
	  foreach my $chr ( @chr_list ) {
	    my $chr_random = $chr . '_random';
	    my $host;
	    my $host_i = 0;
	    do {
	      $host = $lsbhosts[$host_i++];
	    } while(defined($host) && $self->{lsbhosts}{$host} > $jobs_per_host);
	    $self->{lsbhosts}{$host} += 1;
	    $self->{chr_host}{$chr} = $host;
	    $self->{chr_host}{$chr_random} = $host;
	  }
	} elsif (!$self->nobsub) {
		my $suggested_jobs = $num_jobs * 2;
		print "It is highly suggested to run this as:\n\tbsub -oo sxog.out -q long -n $suggested_jobs -R 'select[type==LINUX64] span[ptile=2]' genome-model align-reads sxog ARGS\n";
		print "Use the option: --nobsub to run it anyway.\n";
		exit 0;
	}

	my $pwd = $ENV{PWD};
	foreach my $chr (@chrs) {
	  my $chr_prog = $self->{_chr_program};
	  my $chr_output_base = $self->{_output_base} . "_${chr}";

	  my $c = GSC::Sequence::Chromosome->get(
						 sequence_item_name =>
						 "NCBI-human-build36-chrom$chr"
						);
	  my $chr_length = (defined($c) && defined($c->seq_length)) ?
			    $c->seq_length+1 : '';
	  my $chr_prog_commandline = "$chr_prog $chr $chr_output_base $chr_length ";
	  my $commandline;
	  if ($total_lsbhosts) {
	    my $host = $self->{chr_host}{$chr};
	    if (!defined($host) || $host eq '') {
	      $self->error_message("No host assigned for chromosome: $chr");
	      exit -1;
	    }
	    $commandline = "| ssh -c blowfish $host '( cd $pwd ; $chr_prog_commandline )'";
	  } else {
	    $commandline = "| $chr_prog_commandline";
	  }
	  $fh = $self->{'chr_file'}{$chr} = new IO::File;
	  print "Starting subjob: $commandline\n";
	  my $pid = $fh->open("$commandline");
	  if ($pid == 0) {
	    $self->error_message("Unable to open pipe command: $commandline");
	  }
	  $self->{'sxog_chr_pid'}{$chr} = $pid;
	  $fh->blocking(1);
	}

	my($read_index) = "${output_base}_read_ndx.tsv";
	$fh = new IO::File;
	unless ($fh->open(">$read_index")) {
	  $self->error_message("Unable to open read index file: $read_index");
	  return 0;
	}
	$self->{_read_index_fh} = $fh;

	my($read_indexb) = "${output_base}_read.ndx";
	$fh = new IO::File;
	unless ($fh->open(">$read_indexb")) {
	  $self->error_message("Unable to open read index file: $read_indexb");
	  return 0;
	}
	$self->{_read_indexb_fh} = $fh;

	my($read_datb) = "${output_base}_read.dat";
	$fh = new IO::File;
	unless ($fh->open(">$read_datb")) {
	  $self->error_message("Unable to open read data file: $read_datb");
	  return 0;
	}
	$self->{_read_datb_fh} = $fh;

	my $prb_map_filename = $self->{_prb_map};
	unless (open(PRBMAP,$prb_map_filename)) {
	  $self->error_message("Unable to open prb map file: $prb_map_filename");
	  return 0;
	}
	while(<PRBMAP>) {
	  chomp;
	  my ($lane, $tile, $offset) = split("\t");
	  $self->{_prb_read_map}{"$lane\t$tile"} = $offset;
	}
	close(PRBMAP);

	return $self;
      }

#-------------------------------------------------

sub Close {
  my($self);

  my $chr;
  foreach $chr (@{$self->{'chromosomes'}}) {
    my $fh = $self->{'chr_file'}{$chr};
    for (my $i = 0 ; $i < 32000; $i++) {
      print $fh "END\n";
    }
    $fh->flush();
  }
  foreach $chr (@{$self->{'chromosomes'}}) {
    $self->{'chr_file'}{$chr}->close();
  }
#  my $read_index_fh = $self->{_read_index_fh};
#  $read_index_fh->close();
#  my $read_indexb_fh = $self->{_read_indexb_fh};
#  $read_indexb_fh->close();
#  my $read_datb_fh = $self->{_read_datb_fh} = $fh;
#  $read_datb_fh->close();
}

sub Process {
  my($self,$file) = @_;
  my($basename) = basename($file);
  my ($sxog_lane, $sxog_tile) = $basename =~ /_(\d+)_(\d+)/;
	
  my $run_id = $self->{_run_id};
  my $read_index_fh = $self->{_read_index_fh};
  my $read_indexb_fh = $self->{_read_indexb_fh};
  my $read_datb_fh = $self->{_read_datb_fh};
  my $max_align	= $self->{_max_align};
	
  my($source) = $basename;
  $source =~ s/\_prb\.sxog//;
	if ($file =~ /\.bz2$/x ) {
		unless (open(INFILE, "bzcat $file |")) {
			$self->error_message("Unable to bzcat search result file: $file");
			return 0;
		}
	} else {
		unless (open(INFILE, $file)) {
			$self->error_message("Unable to open search result file: $file");
			return 0;
		}
	}
  my ($in_read_id, $read_id, $num_align, $seq_id, $chromosome);
	#  my ($threshold, $ref_start, $ref_end, $ref_seq, $sequence, $q_start, $q_end);
  my ($aln_string) = 'NOTUSED';
  my ($q_seq, $ref_seq);
  my ($orientation, $read_len);
  my ($alignment_probability_unnormalized);
  my ($running_total_of_probabilities_for_this_read);
  my (@alignments);
  my ($snp_probability) = 0;
  my ($score_base);
  my $read_offsetb = $read_datb_fh->tell();
	
  my $read_number = $self->{_read_number};
  my $prb_read_number = $self->{_prb_read_map}{"$sxog_lane\t$sxog_tile"};
  if ($prb_read_number != $read_number) {
    $self->error_message("At sxog file: $basename resetting read number: $read_number to prb map value: $prb_read_number");
    $read_number = $prb_read_number;
  }
	
	# Process header
  while(<INFILE>) {
    chomp;
    if (/^ \s* \# /xo ) {
      if (/-p ([\d\.]+)/o ) {
				# extract snp probability since we have to reverse it out
				$snp_probability = $1;
				$snp_probability ||= 0;
      }
    } else {
      $snp_probability = (!defined($snp_probability)) ? 0.0 : $snp_probability;
      $score_base = exp(
												log($snp_probability + .001 - $snp_probability * .001)
												/
												-10
											 );
      goto AFTERHEADER;
    }
  }
	
	# Now process the remainder
  while(<INFILE>) {
    chomp;
  AFTERHEADER:
    if ( /^
							 \>			# A '>' at the start of the line
							 \s*			# Any spaces
							 (.*)			# The rest of the line
							 \s*
							 $
							 /xo) {
      my $tmp_read_id = $1;
      ($in_read_id) = $tmp_read_id =~ /\s* (\d+) \s*/xo;
			
      # Process any existing
      if (defined($read_id) && $read_id ne '' && $num_align == 0) {
				$read_offsetb = 0;
      }
			
      if (defined($read_id) && $read_id ne '') {
				if ($num_align < $max_align) {
					foreach my $alignment (@alignments) {
						my ($out_chromosome, $out_read_id, $out_start, $out_read_len, $out_orientation,
								$out_num_align, $out_score,
								$out_q_seq, $out_aln_string, $out_ref_seq, $out_seq_id) = @{$alignment};
						$out_score = $out_score / $running_total_of_probabilities_for_this_read;
						if (!defined($out_read_id) ||
								!defined($out_start) ||
								!defined($out_read_len) ||
								!defined($out_orientation) ||
								!defined($out_num_align) ||
								!defined($out_score) ||
								!defined($out_q_seq) ||
								!defined($out_aln_string) ||
								!defined($out_ref_seq) ||
								!defined($out_seq_id)) {
							$self->error_message('Bad input: ' .
														 join(' ',@{$alignment}) . " in file: $file");
						} else {
							my $fh = $self->{'chr_file'}{$out_chromosome};
							print $fh "$out_read_id $out_start $out_read_len $out_orientation $out_num_align $out_score $out_q_seq $out_aln_string $out_ref_seq $out_seq_id\n";
							$fh->flush();
						}
					}
				}
				
				$running_total_of_probabilities_for_this_read = 0;
				@alignments = ();

				print $read_index_fh "$read_id\t$source\t$in_read_id\t$num_align\t$read_offsetb\n";
#	print $read_indexb_fh pack('QZ22SLQ',
				print $read_indexb_fh pack('L!Z22SLL!',
																	 $read_id,$source,
																	 $in_read_id,$num_align,$read_offsetb);
				$read_offsetb = $read_datb_fh->tell();
      }
      $read_id = ($run_id * 1000000000) + (++$read_number);
      $num_align = 0;		# Default is no alignments
#      $sequence = '';
    } elsif ( /
							 (\d+) \s+ alignments \s+ at \s+ threshold \s+ of \s+ ([\-\d]+)
							 /xo ) {
#      ($num_align, $threshold) = ($1, $2);
      $num_align = $1;

			if (0 < $num_align && $num_align < $max_align) {
				while(<INFILE>) {
					my $first_char = substr($_,0,1);
					if ($first_char eq '>') {
						goto AFTERHEADER;
					} elsif ($first_char eq ' ') {
						chomp;
						my $next_chars = substr($_,1,2);
						if ($next_chars eq 'Qu') {
							my ($start,$seq,$end) = /^ \s+ Query: \s+ (\d+) \s+ ([XACGTN\-]+) \s+ (\d+) \s*/xo;
							$q_seq = $seq;
							$q_seq =~ tr/X/N/;
							if ($start > $end) {
								$read_len = $start;
								$orientation = '0';
							} else {
								$read_len = $end;
								$orientation = '1';
							}
						} elsif ($next_chars eq 'Sb') {
							my ($start,$seq,$end) = /^ \s+ Sbjct: \s+ (\d+) \s+ ([XACGTN\-]+) \s+ (\d+) \s*/xo;
							$seq_id =~ s/\s+/_/go;
							print $read_datb_fh pack("Z4L",$chromosome,$start);
							push @alignments, [ $chromosome,
																	$read_id, $start, $read_len, $orientation,
																	$num_align,
																	$alignment_probability_unnormalized,
																	$q_seq, $aln_string, $seq, $seq_id
																];
						} elsif ($next_chars eq 'Sc') {
						  my ($num_score) = /^\s+ Score \s+ \= \s+ (\-?\d+) \s*/xo;
							$alignment_probability_unnormalized = $score_base**$num_score;
							$running_total_of_probabilities_for_this_read +=
								$alignment_probability_unnormalized;
						} elsif ( /^
											 \s+		# A space if a read alignment
											 \>		# A '>' at the start of the line
											 /xo ) {
							# Sequence id line: ^\s>gi|89161210|ref|NC_000006.10|NC_000006 Homo sapiens chromosome 6, reference assembly, complete sequence
							s/^\s*\>//xo;
							$seq_id = $_;
							($chromosome) = /\b chromosome \s+ ([^\,]+) \, /xo;
							$chromosome ||= ${$self->{'chromosomes'}}[0];
#						} elsif ( /^ \s+ ([\|\s\d]+) \s*/xo ) {
#							$aln_string = $1;
						}
					}
				}
			} else {
				$num_align = 0;
				# Get to the next read record
				while(<INFILE>) {
					if (substr($_,0,1) eq '>') {
						goto AFTERHEADER;
					}
				}
			}
#    } elsif (/^ \s* ([ACGTN\-\s]+) \s* $ /xo) {
#      $sequence = $1;
#    } elsif (/^ \s* $ /xo ) {
#			#      1;			# Blank line
#    } else {
#      $self->error_message("Unexpected line in file: $_");
    }
  }

	# Process any existing
	foreach my $alignment (@alignments) {
		my ($out_chromosome, $out_read_id, $out_start, $out_read_len, $out_orientation, 
				$out_num_align, $out_score, 
				$out_q_seq, $out_aln_string, $out_ref_seq, $out_seq_id) = @{$alignment};
		$out_score = $out_score / $running_total_of_probabilities_for_this_read;
		if (!defined($out_read_id) ||
				!defined($out_start) ||
				!defined($out_read_len) ||
				!defined($out_orientation) ||
				!defined($out_num_align) ||
				!defined($out_score) ||
				!defined($out_q_seq) ||
				!defined($out_aln_string) ||
				!defined($out_ref_seq) ||
				!defined($out_seq_id)) {
			$self->error_message('Bad input: ' .
										 join(' ',@{$alignment}) . " in file: $file");
		} else {
			my $sxog_chr_fh = $self->{'chr_file'}{$out_chromosome};
			print $sxog_chr_fh "$out_read_id $out_start $out_read_len $out_orientation $out_num_align $out_score $out_q_seq $out_aln_string $out_ref_seq $out_seq_id\n";
			$sxog_chr_fh->flush();
		}
	}
  
  if (defined($read_id)) {
    print $read_index_fh "$read_id\t$source\t$in_read_id\t$num_align\n";
#    print $read_indexb_fh pack('QZ22SLQ',
    print $read_indexb_fh pack('L!Z22SLL!',
			       $read_id,$source,
			       $in_read_id,$num_align,$read_offsetb);
  }
  close(INFILE);

  $self->{_read_number} = $read_number;

  return 1;
}

#-------------------------------------------------

1;

