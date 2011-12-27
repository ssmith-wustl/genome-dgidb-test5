package Genome::Model::Tools::Sx::Quake;

use strict;
use warnings;

use Genome;

require Cwd;

our %QUAKE_PARAMS = (
    k => {
        is => 'Number',
        doc => 'Size of k-mers to correct.',
    },
    p => {
        is => 'Number',
        is_optional => 1,
        doc => 'Number of processes.',
    },
    no_jelly => {
        is => 'Boolean',
        is_optional => 1,
        doc => 'Count k-mers using a simpler program than Jellyfish.'
    },
    no_count => {
        is => 'Boolean',
        is_optional => 1,
        doc => 'Kmers are already counted and in expected file [reads file].qcts or [reads file].cts [default: False].',
    },
    'int' => {
        is => 'Boolean',
        is_optional => 1,
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
        doc => 'Coverage model is optimized and cutoff was printed to expected file cutoff.txt [default: False].'
    },
    ratio => {
        is => 'Number',
        is_optional => 1,
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
        save_files => {is=> 'Boolean', is_optional => 1, doc => 'Save quake output files' },
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
        config => [ $quake_input.':type=sanger', ],
    );
    if ( not $quake_intput_writer ) {
        $self->error_message('Failed to open temp quake input!');
        return;
    }

    $self->status_message('Write quake input: '.$quake_input);
    my $reader = $self->_input;
    my $seqs = $reader->read;
    my $cnt = @$seqs; 
    do {
        $quake_intput_writer->write($seqs);
    } while $seqs = $reader->read;
    $self->status_message('Write quake input...OK');

    $self->status_message('Run quake');
    my $quake = $self->_run_quake_command($quake_input);
    return if not $quake;
    $self->status_message('Run quake..OK');

    my $quake_output = $tmpdir.'/quake.cor.fastq';

    my $quake_output_reader = Genome::Model::Tools::Sx::FastqReader->create(
        file => $quake_output,
    );
    if ( not $quake_output_reader ) {
        $self->error_message('Failed to open reader for quake output!');
        return;
    }

    $self->status_message('Read quake output: '.$quake_output);
    my $writer = $self->_output;

    if ( $cnt == 1 ) { 
        $self->status_message('Writing as singles');
        while ( my $seq = $quake_output_reader->read ) {
            $writer->write([ $seq ]);
        }
    }
    else { # collect sets
        $self->status_message('Writing as sets');
        my $regexp = qr{/\d+$|\.[bg]\d+$};
        my @seqs = ( $quake_output_reader->read );
        my $set_id = $seqs[0]->{id};
        $set_id =~ s/$regexp//;
        while ( my $seq = $quake_output_reader->read ) {
            my $seq_id = $seq->{id};
            $seq_id =~ s/$regexp//;
            if ( $seq_id ne $set_id ) {
                $writer->write(\@seqs);
                # reset the set
                @seqs = (); 
                $set_id = $seq->{id};
                $set_id =~ s/$regexp//;
            }
            push @seqs, $seq;
        }
        $writer->write(\@seqs) if @seqs;
    }
    $self->status_message('Read quake output...OK');

    $self->_copy_quake_files if $self->save_files;

    return 1;
}

sub _run_quake_command {
    my ($self, $file) = @_;

    my $cwd = Cwd::getcwd();
    chdir $self->_tmpdir; # quake dumps files in the cwd!
    $self->status_message('Chdir to: '.$self->_tmpdir);

    my $cmd = 'quake.py -q 33 -r '.$file;
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

    chdir $cwd;
    $self->status_message('Chdir back to: '.$cwd);
    if ( not $rv ) {
        $self->error_message($@) if $@;
        $self->error_message("Failed to run quake: $cmd");
        return;
    }

    return $cmd;
}

sub _copy_quake_files {
    my $self = shift;

    my $output_directory = $self->_directory_from_output;
    $self->status_message('Failed to derive assembly directory from sx output') and return
        if not $output_directory;

    Genome::Sys->create_directory( $output_directory.'/Quake' ) if
        not -d $output_directory.'/Quake';
    $output_directory .= '/Quake';

    $self->status_message("Copying quake output files to $output_directory");
    for my $file ( glob( $self->_tmpdir.'/*' ) ){
        $self->status_message("Copying file: $file");
        #prevent copying of Quake dir to itself if it runs in tmpdir or
        #same dir as input file
        next if File::Basename::basename($file) eq 'Quake';
        File::Copy::copy( $file, $output_directory );
    }
    $self->status_message('Finished copying quake output files');

    return 1;
}

sub _directory_from_output {
    my $self = shift;

    my ( $class, $params ) = $self->_output->parse_writer_config( $self->_output->config );
    return if not $class or not $params;

    my $dir = File::Basename::dirname($params->{file});
    return if not -d $dir;

    return $dir;
}

1;

