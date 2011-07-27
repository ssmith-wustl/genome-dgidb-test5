package Genome::Model::Tools::Maq::Map;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::Map {
    is => 'Genome::Model::Tools::Maq',
    has_input => [
        use_version => {
            is => 'String',
            doc => 'Version of maq to use',
            is_optional => 1,
            default_value => '0.7.1',
        },
        bfa_file => {
            doc => 'Required input file name containing the reference sequence file(.bfa)',
            is => 'String',
        },
        fastq_files => {
            is_optional => 1,
            doc => 'A file or a pipe separated list of Paired End files containing the reads to be aligned in binary fastq format(.bfq)',
        },
        output_directory => {
            is => 'String',
            doc => 'The alignment directory where output files are written',
        },
        quality_converter => {
            is => 'String',
            is_optional => 1,
            doc => 'The algorithm to use for converting fastq quality scores, sol2sanger(old) or sol2phred(new)',
        },
    ],
    has_param => [
        lsf_queue => {
            is_optional => 1,
            default_value => 'long',
        },
        lsf_resource => {
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
        },
        params => {
            doc => 'The maq map parameters. These should be specified in a quoted string with single dashes, e.g. "-x 1 -y -z"',
            is => 'String',
            is_optional => 1,
            default_value => '',
        },
    ],
    has_output => [
        output_file => {
            doc => 'Output log file containing results and error messages from MAQ.',
            is_optional => 1,
            is => 'String',
        },
        map_file => {
            doc => 'Output file containing the aligned map data.',
            is_optional => 1,
            is => 'String',
        },
        unaligned_file => {
            doc => 'Output file containing the unaligned data.',
            is_optional => 1,
            is => 'String',
        },
    ],
    has_optional => [
        _fastq_count => { },
    ],
};

sub execute {
    my $self = shift;

    my @fastq_files;
    if (ref($self->fastq_files) eq 'ARRAY') {
        @fastq_files = @{$self->fastq_files};
    } else {
        push @fastq_files, $self->fastq_files;
    }
    my $fastq_count = scalar(@fastq_files);
    if ($fastq_count > 2) {
        die('Too many fastq files passed to map command');
    }
    $self->_fastq_count($fastq_count);
    my @suffix = qw/txt fastq/;
    my @output_basenames;
    my @bfq_files;
    my @files_to_unlink;
    for my $fastq_file (@fastq_files) {
        my ($basename,$dirname,$suffix) = File::Basename::fileparse($fastq_file,@suffix);
        unless ($basename  && $dirname && $suffix) {
            die('Failed to parse fastq file name '. $fastq_file);
        }
        $basename =~ s/\.$//;
        push @output_basenames, $basename;
        #Convert Quality Values
        if ($self->quality_converter) {
            my $tmp_fastq = Genome::Sys->create_temp_file_path($basename.'.fastq');
            if ($self->quality_converter eq 'sol2sanger') {
                my $sol2sanger = Genome::Model::Tools::Maq::Sol2sanger->create(
                    solexa_fastq_file => $fastq_file,
                    sanger_fastq_file => $tmp_fastq,
                    use_version => $self->use_version,
                );
                unless ($sol2sanger) {
                    die('Failed to create sol2sanger quality converion command');
                }
                unless ($sol2sanger->execute) {
                    die ('Failed to execute sol2sanger quality conversion command');
                }
            } elsif ($self->quality_converter eq 'sol2phred') {
                my $sol2phred = Genome::Model::Tools::Fastq::Sol2phred->create(
                    fastq_file => $fastq_file,
                    phred_fastq_file => $tmp_fastq,
                );
                unless ($sol2phred) {
                    die('Failed to create sol2phred quality conversion command');
                }
                unless ($sol2phred->execute) {
                    die('Failed to execute sol2phred quality conversion command');
                }
            } else {
                die('Failed to recognize quality converter '. $self->quality_converter);
            }
            $fastq_file = $tmp_fastq;
            push @files_to_unlink, $tmp_fastq;
        }
        #Convert To Binary
        my $tmp_bfq = Genome::Sys->create_temp_file_path($basename .'.bfq');
        my $fastq2bfq = Genome::Model::Tools::Maq::Fastq2bfq->create(
            use_version => $self->use_version,
            fastq_file => $fastq_file,
            bfq_file => $tmp_bfq,
        );
        unless ($fastq2bfq) {
            die('Failed to create fastq2bfq conversion command');
        }
        unless ($fastq2bfq->execute) {
            die('Failed to execute fastq2bfq conversion command');
        }
        push @bfq_files,$tmp_bfq;
        push @files_to_unlink, $tmp_bfq;
    }

    my $output_basename;
    if ($fastq_count == 2) {
        my $lane;
        for my $end_output_basename (@output_basenames) {
            unless ($end_output_basename =~ m/((\d)_[12])/) {
                die('Failed to parse lane and end from file basename '. $end_output_basename);
            }
            my $read_id = $1;
            my $read_lane = $2;
            if ($lane) {
                unless ($lane == $read_lane) {
                    die('Fastq files do not contain reads from the same lane');
                }
            } else {
                $lane = $read_lane;
            }
            $end_output_basename =~ s/$read_id/$lane/;
            $output_basename = $end_output_basename;
        }
    } elsif ($fastq_count == 1) {
        $output_basename = $output_basenames[0];
    } else {
        die('Invalid number of fastq files '. $fastq_count);
    }
    $self->map_file($self->output_directory .'/'. $output_basename .'.map');
    $self->output_file($self->output_directory .'/'. $output_basename .'.out');
    $self->unaligned_file($self->output_directory .'/'. $output_basename .'.unaligned');

    my $cmdline = $self->maq_path
        . sprintf(' map %s -u %s %s %s %s > ',
                  $self->params,
                  $self->unaligned_file,
                  $self->map_file,
                  $self->bfa_file,
                  join(' ', @bfq_files))
        . $self->output_file
        . ' 2>&1';
    Genome::Sys->shellcmd(
        cmd                         => $cmdline,
        input_files                 => [$self->bfa_file, @bfq_files],
        # $self->unaligned_file is really optional, what if all reads aligned
        # is there still an empty file?  are empty files ok?
        output_files                => [$self->map_file, $self->output_file],
    );
    for my $file (@files_to_unlink) {
        unless (unlink $file) {
            die('Failed to remove file '. $file ,":  $!");
        }
    }
    $self->_verify_output_files;
    return 1;
}

sub _verify_output_files {
    my $self = shift;

    my $output_fh = IO::File->new($self->output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $self->output_file .": $!");
        die($self->error_message);
    }
    my @lines = <$output_fh>;
    $output_fh->close;
    my $complete = 0;
    my $is_PE = undef;
    for my $line (@lines) {
        chomp($line);
        if ($line =~ m/match_data2mapping/) {
            $complete = 1;
        }
        if ($line =~ m/\[match_index_sorted\] no reasonable reads are available. Exit!/) {
            $complete = 1;
        }
        if ($line =~ m/total, isPE, mapped, paired/) {
            my ($comma_separated_metrics) = ($line =~ m/= \((.*)\)/);
            my @values = split(/,\s*/,$comma_separated_metrics);
            $is_PE = $values[1];
        }
    }
    if ( ($self->_fastq_count == 2) ) {
        unless ($is_PE == 1) {
            die ('Failed to align '. $self->_fastq_count .' fastq files as paired end');
        }
    } else {
        unless ($is_PE == 0) {
            die ('Failed to align '. $self->_fastq_count .' fastq file as fragment');
        }
    }
    unless ( $complete ) {
        die('Incomplete output file '. $self->output_file);
    }
    my $validate = Genome::Model::Tools::Maq::Mapvalidate->execute(
        map_file => $self->map_file,
        output_file => '/dev/null',
        use_version => $self->use_version,
    );
    unless ($validate) {
        die('Failed to validate map file '. $self->map_file);
    }
}

1;
