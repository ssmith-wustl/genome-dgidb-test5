package Genome::Model::Tools::Sx::Quake;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

our %QUAKE_PARAMS = (
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
    is  => 'Genome::Model::Tools::Sx',
    has => [ 
        %QUAKE_PARAMS,
        _tmpdir => { is_transient => 1, is_optional => 1, },
    ],
};

sub quake_param_names {
    return sort keys %QUAKE_PARAMS;
}

sub help_brief {
    return 'Correct substitution errors with deep coverage.';
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $tmpdir = $self->_tmpdir( Genome::Sys->base_temp_directory );

    my $quake_input = $tmpdir.'/quake.fastq';
    my $quake_intput_writer = Genome::Model::Tools::Sx::Writer->create(
        config => [ $quake_input.':type=sanger' ],
    );
    if ( not $quake_intput_writer ) {
        $self->error_message('Failed to open temp quake input!');
        return;
    }

    $self->status_message('Write quake input: '.$quake_input);
    my $reader = $self->_input;
    while ( my $seqs = $reader->read ) {
        $quake_intput_writer->write($seqs);
    }
    $self->status_message('Write quake input...OK');

    $self->status_message('Run quake');
    my $quake = $self->_run_quake_command($quake_input);
    return if not $quake;
    $self->status_message('Run quake..OK');

    my $quake_output = $tmpdir.'/quake.cor.fastq';
    my $quake_output_reader = Genome::Model::Tools::Sx::Reader->create(
        config => [ $quake_output.':type=sanger' ],
    );
    if ( not $quake_output_reader ) {
        $self->error_message('Failed to open reader for quake output!');
        return;
    }

    $self->status_message('Read quake output: '.$quake_output);
    my $writer = $self->_output;
    while ( my $seqs = $quake_output_reader->read ) {
        $writer->write($seqs);
    }
    $self->status_message('Read quake output...OK');

    return 1;
}

sub _run_quake_command {
    my ($self, $file) = @_;

    my $cmd = 'quake.py -f '.$file;
    my $meta = $self->__meta__;
    for my $key ( $self->quake_param_names ) {
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
        $self->error_message($@) if $@;
        $self->error_message("Failed to run quake: $cmd");
        return;
    }

    return $cmd;
}

1;

