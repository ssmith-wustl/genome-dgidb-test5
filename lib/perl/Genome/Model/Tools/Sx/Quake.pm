package Genome::Model::Tools::Sx::Quake;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

our %QUAKE_PARAMS = (
    r =>  {
        is => 'Text',
        is_optional => 1,
        doc => 'Fastq file of reads',
    },
    f => {
        is => 'Text',
        is_optional => 1,
        doc => 'File containing fastq file names, one per line or two per line for paired end reads.',
    },
    q => {
        is => 'Number',
        is_optional => 1,
        valid_values => [qw/ 33 64 /],
        doc => 'Quality value ascii scale, generally 64 or 33. If not specified, it will guess.',
    },
    k => {
        is => 'Number',
        doc => 'Size of k-mers to correct.',
    },
    p => {
        is => 'Number',
        default_value => 4,
        doc => 'Number of processes.',
    },
    no_jelly => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Count k-mers using a simpler program than Jellyfish.'
    },
    no_count => {
        is => 'Boolean',
        doc => 'Kmers are already counted and in expected file [reads file].qcts or [reads file].cts [default: False].',
        default_value => 0,
    },
    'int' => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Count kmers as integers w/o the use of quality values [default: False].',
    },
    hash_size => {
        is => 'Number',
        is_optional => 1,
        doc => 'Jellyfish hash-size parameter. Quake will estimate using k if not given',
    },
    no_cut => {
        is => 'Boolean',
        is_optional => 1,
        default_value => 0,
        doc => 'Coverage model is optimized and cutoff was printed to expected file cutoff.txt [default: False].'
    },
    ratio => {
        is => 'Number',
        is_optional => 1,
        default_value => 200,
        doc => 'Likelihood ratio to set trusted/untrusted cutoff.  Generally set between 10-1000 with lower numbers suggesting a lower threshold. [default: 200].',
    },
    l => {
        is => 'Number',
        is_optional => 1,
        doc => 'Return only reads corrected and/or trimmed to <min_read> bp.',
    },
    u => {
        is => 'Boolean',
        is_optional => 1,
        doc => 'Output error reads even if they can\'t be corrected, maintaing paired end reads.',
    },
    t => {
        is => 'Number',
        is_optional => 1,
        doc => 'Use BWA-like trim parameter <trim_par>'
    },
    headers => {
        is => 'Boolean',
        is_optional => 1,
        doc => 'Output only the original read headers without correction messages.',
    },
    'log' => {
        is => 'Boolean',
        is_optional => 1,
        doc => 'Output a log of all corrections into *.log as "quality position new_nt old_nt".',
    },
);

class Genome::Model::Tools::Sx::Quake {
    is  => 'Command::V2',
    has => [ %QUAKE_PARAMS ],
};

sub quake_param_names {
    return sort keys %QUAKE_PARAMS;
}

sub help_brief {
    return 'QUAKE: Correct substitution errors with deep coverage.';
}

sub execute {
    my $self = shift;

    my $cmd = 'quake.py';
    my $meta = $self->__meta__;
    for my $key ( sort keys %QUAKE_PARAMS ) {
        my $property = $meta->property_meta_for_name($key);
        my $value = $self->$key;
        next if not defined $value;
        $cmd .= sprintf(
            ' %s%s%s',
            ( length($key) == 1 ? '-' : '--'),                      # - or --
            $key,                                                   # param name
            ( $property->data_type eq 'Boolean' ? '' : ' '.$value ),  # value or empty string for boolean
        );
    }
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message('Failed to run quake: '.$cmd);
        return;
    }

    return 1;
}

1;

