
package Genome::Model::Tools::Fasta::FastaToSpool;

use strict;
use warnings;
use English;

use Genome;

use Cwd;
use File::Basename;
use File::Path   qw(rmtree);
use Archive::Zip qw(:ERROR_CODES);

use Bio::SeqIO;

class Genome::Model::Tools::Fasta::FastaToSpool {
    is => 'Command',
    has => [
        reads => {
            is => 'Integer',
            is_input => 1,
            is_optional => 1,
            doc => 'Number of reads per batch file',
            default => 100,
        },
        batches => {
            is => 'Integer',
            is_input => 1,
            is_optional => 1,
            doc => 'Number of batches per spool directory',
            default => 100,
        },
        fasta => {
            is => 'String',
            is_input => 1,
            is_optional => 0,
            doc => 'FASTA file',
            default => undef,
        },
        spooldir => {
            is => 'String',
            is_output => 1,
            is_optional => 0,
            doc => 'Spool directory created',
            default => undef,
        },
        start => {
            is => 'Integer',
            is_input => 1,
            is_optional => 1,
            doc => 'Skip to the first read of this batch N',
            default => 0,
        },
        end => {
            is => 'Integer',
            is_input => 1,
            is_optional => 1,
            doc => 'Stop after this batch N',
            default => 0,
        },
        force => {
            is => 'boolean',
            is_input => 1,
            is_optional => 1,
            doc => 'Overwrite existing files if present',
            default => 0,
        },
        compress => {
            is => 'boolean',
            is_input => 1,
            is_optional => 1,
            doc => 'Put spools into zip files rather than directories',
            default => 0,
        },
        prefix => {
            is => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'Prefix + fasta = spoolname',
            default => 'spool',
        }
    ],
};

sub help_brief {
  'Divide a FASTA file into a set of batch files in subdirectories, for use with a Spooler, see LSFSpool and BlastxSpool.'
}

sub help_detail {
  return <<EOT
   Create a top level "spool" directory and divide a FASTA file into a set of
smaller batch files within sub directories of that top level spool directory.
Optionally zip/compress the spool directory into a zip file.
EOT
}

sub help_synopsis {
  return <<EOT
genome model tools fasta fasta-to-spool [--force] [--reads N] [--batches N] [--start N] [--end N] [--compress] --fasta FILE

genome model tools fasta fasta-to-spool --reads 10 --batches 10 --fasta FILE
EOT
}

sub create {
  my $class = shift;
  my $self = $class->SUPER::create(@_);

  my $prefix = $self->{prefix};
  my $fasta = Cwd::abs_path $self->{fasta};
  my $filename = basename $fasta;
  my $spooldir = dirname $fasta;

  $spooldir .= "/$prefix-$filename";
  $self->{spooldir} = $spooldir;

  return $self;
}

sub compress {
  # Compress a directory of batch files
  my $self = shift;
  my $jobname = shift;

  return if (!defined($jobname));

  # Open a possibly pre-existing zip archive.
  my $zip = Archive::Zip->new();
  if (-f "$jobname.zip") {
    my $status = $zip->read("$jobname.zip");
    die "Error in archive $jobname.zip: $!" if (! $status == AZ_OK );
  }

  # Traverse a directory and add batch files to the zip.
  opendir(OD,$jobname) or die "Cannot enter dir $jobname: $!";
  for my $bfile (readdir OD) {
    $zip->addFile("$jobname/$bfile",basename($bfile));
  }
  closedir(OD);

  # Write the zip.
  unless ( $zip->overwriteAs("$jobname.zip") == AZ_OK ) {
    die "Error writing archive $jobname.zip: $!";
  }

  # Remove the temporary path.
  rmtree($jobname) or die "Cannot rmtree $jobname: $!";
  print "Compressed to $jobname.zip\n";
}

sub execute {
  # Traverse a FASTA file, writing reads to output files and directories.
  my $self = shift;
  my $fasta = $self->{fasta};

  if ($self->{start} and $self->{end} and
      $self->{end} <= $self->{start}) {
    $self->error_message("The 'end' must be greater than the 'start' job");
    return;
  }

  my $wait = 0;
  if ($self->{'start'}) {
    $wait = $self->{'start'} * $self->{reads} * $self->{batches};
    print "Start at job $self->{start} = $wait reads\n";
  }

  # Reads go in a batch file
  my $reads = 0;
  # Total reads read, to track progress through the input file
  my $totalreads = 0;
  # Bytes read
  my $sizeread = 0;
  # Batch file counter
  my $batch = 1;
  # A "job" is a set of batch files of size batches
  my $jobcount = 1;
  # A jobname is a directory or zip file containing batch files.
  my $jobname;

  # A batch file is a file containing reads.
  my $bfilename;

  # Input file
  my $ifasta;
  # Output file
  my $ofasta;

  # Size of the input FASTA file in bytes.
  my $totalsize = (stat $fasta)[7];

  # We use BIO::SeqIO to avoid shelling out to something like grep,
  # and this is a bit faster than my naive attempts at reading lines.
  $ifasta = Bio::SeqIO->new(-file => "<$fasta", -format => "fasta" );

  # Make the base spool
  if (! -d $self->{spooldir} ) {
    mkdir $self->{spooldir} or die "Cannot mkdir spooldir $self->{spooldir}: $!";
  }
  chdir $self->{spooldir} or die "Cannot chdir spooldir $self->{spooldir}: $!";

  # Begin parsing input file
  while ( my $seq = $ifasta->next_seq() ) {

    $reads += 1;
    $totalreads += 1;
    $sizeread += length($seq);

    # Here we reach the size limit of a batch file.
    if ( $reads > $self->{reads} ) {
      $reads = 1;
      $batch += 1;
      $ofasta->DESTROY() if defined($ofasta);
      undef $ofasta;
    }

    # Here we reach the job size limit.
    if ( defined $self->{batches} and
          $batch > $self->{batches} ) {
      # Compress the last job
      compress($jobname) if ($self->{compress});
      # Start a new job directory.
      # We'll keep making jobs until EOF or "end" limit below.
      $batch = 1;
      $jobcount += 1;
      if ( $self->{end} and
                   $jobcount > $self->{end}) {
        print "Reached maximum number of batch files\n";
        return;
      }
    }

    # Wait to do work if a start mark is set, skipping to the given job.
    if (defined $self->{start}) {
      if ($totalreads < $wait) {
        next;
      } else {
        undef $self->{start};
      }
    }

    # Track output file.
    if (!defined($ofasta)) {
      # Job name is a directory or zip archive.
      my $filename = basename $self->{fasta};
      $jobname = "$self->{prefix}-$filename-$jobcount";
      # Batch file name is a file containing reads.
      $bfilename = "$jobname-$batch";
      $bfilename = "$jobname/$bfilename";

      if ( -f $bfilename and ! $self->{force}) {
        die "Cowardly refusing to clobber existing batchfile: $bfilename";
      }
      if ( -f $jobname and ! $self->{force}) {
        die "Cowardly refusing to clobber existing job directory: $jobname";
      }
      if ( -f "$jobname.zip" and $self->{compress} and
           ! $self->{force}) {
        die "Cowardly refusing to clobber existing job archive: $jobname.zip";
      }
      if (! -d $jobname) {
        printf "Create job dir %s (%d/%d) with %d batches\n",$jobname,$jobcount,$self->{end},$self->{batches};
        mkdir($jobname) or die "Cannot mkdir $jobname: $!";
      }

      printf "Create batch file $bfilename with %d reads\n",$self->{reads};
      open(OF, ">$bfilename") or die "Failed to open $bfilename: $!";
      $ofasta = Bio::SeqIO->new(-fh => \*OF, -format => "fasta" ) or die "Failed to make new SeqIO: $!";
    }

    # Write output
    # write_seq defaults width to 60 and cannot be disabled, set long.
    $ofasta->width( 1000 );
    $ofasta->write_seq( $seq ) or die "Failed to write to $bfilename: $!";
  }

  # After we've traversed the input file, close up file in progress.
  $ofasta->DESTROY() if defined($ofasta);
  undef $ofasta;
  compress($jobname) if ($self->{compress});
}

1;

__END__
=pod

=head1 NAME

  FastaToSpool - Break a FASTA file into a directory containing smaller batches.

=head1 SYNOPSIS

  FastaToSpool [--force] [--reads N] [--batches N] [--start N] [--end N] [--compress] --fasta FILE

=head1 OPTIONS

  --force         Overwrite existing files if present.
  --reads   <N>   Number of reads per batch file.
  --batches <N>   Number of batch files per jobs.
  --start   <N>   Skip to the first read of job N.
  --end     <N>   Stop after job N.
  --compress      Put output batch jobs to zip archives.
  --fasta <file>  This is the input FASTA file.

=head1 DESCRIPTION

This is a simple program to batch a FASTA formatted ascii text file into
smaller chunks with a logical naming scheme for use with a Spooler program.
Output will either be smaller FASTA files in subdirectories, or zip archives
containing those smaller FASTA files.

=head1 EXAMPLES

s_7_1_for_bwa_input.pair_a is a FASTA file with 18 million reads.

  # ls -lh s_7_1_for_bwa_input.pair_a
  -rw-rw-r-- 1 user users 2.0G 2009-12-15 12:45 s_7_1_for_bwa_input.pair_a

We want to break it up into manageble chunks for processing with BLASTX.

  # FastaToSpool --reads 500 --batches 100 --fasta s_7_1_for_bwa_input.pair_a

This will produce a toplevel directory 'spool-s_7_1_for_bwa_input.pair_a' which
will contain a number of subdirectories that each contain 100 batch files of
500 reads each.

Your directory will look like:

  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-1/spool-s_7_1_for_bwa_input.pair_a-1-1
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-1/spool-s_7_1_for_bwa_input.pair_a-1-2
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-1/spool-s_7_1_for_bwa_input.pair_a-1-3
  ...
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-1/spool-s_7_1_for_bwa_input.pair_a-1-M
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-2
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-2/...
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-3
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-3/...
  ...
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-N
  spool-s_7_1_for_bwa_input.pair_a/spool-s_7_1_for_bwa_input.pair_a-N/...

You can now process this B<spool directory> using, for example, B<lsf_spool.pl>

  # lsf_spool.pl -p spool-s_7_1_for_bwa_input.pair_a

=head1 KNOWN ISSUES

BIO::SeqIO->write_seq() does some formatting such that batchfiles are not
exactly the same as input files.  Changes are whitespace, and I'm not sure
we care.

=head1 AUTHOR

  Matthew Callaway <mcallawa at genome dot wustl dot edu>

=head1 COPYRIGHT

  Copyright (C) 2010 Washington University Genome Center

  This program is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

