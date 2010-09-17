package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;
require IPC::Run;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
    has => [
        _read_processor_pipe_command => {
            is => 'Text',
            is_optional => 1,
        },
        _current_base_limit => {
            is => 'Integer',
            is_optional => 1,
        },
    ],
};

sub bsub_rusage {
    return "-R 'select[type==LINUX64 && tmp>20000] rusage[tmp=20000] span[hosts=1]'"
}

sub _tempdir {
    my $self = shift;

    unless ( $self->{_tempdir} ) {
        $self->{_tempdir} = File::Temp::tempdir(CLEANUP => 1 );
        Genome::Utility::FileSystem->validate_existing_directory( $self->{_tempdir} )
            or die;
    }
    
    return $self->{_tempdir};
}

sub _metrics_file { 
    return $_[0]->_tempdir.'/coverage.metrics';
}

#< Execute >#
sub execute {
    my $self = shift;

    $self->status_message('Preparing instrument data for '.$self->processing_profile->assembler_name);

    $self->status_message('Checking instrument data...');
    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }
    $self->status_message('Instrument data OK');

    $self->status_message('Setup base limit');
    $self->_setup_base_limit;

    $self->status_message('Start processing instrument data');
    my $sequencing_platform = $self->processing_profile->sequencing_platform;
    my $file_method = '_fastq_files_from_'.$sequencing_platform;
    INST_DATA: for my $instrument_data ( @instrument_data ) {
        $self->_process_instrument_data($instrument_data)
            or return;
        if ( $self->_is_there_a_base_limit_and_has_it_been_exceeded ) {
            last INST_DATA;
        }
    }
    $self->status_message('Done processing instrument data');

    return 1;
}
#<>#

#< Base Limit >#
sub _setup_base_limit {
    my $self = shift;

    my $base_limit = $self->build->calculate_base_limit_from_coverage;
    if ( defined $base_limit ) {
        $self->_current_base_limit($base_limit);
    }

    return 1;
}

sub _is_there_a_base_limit_and_has_it_been_exceeded {
    my $self = shift;

    my $base_limit = $self->_current_base_limit;
    if ( defined $base_limit and $base_limit > 0 ) {
        return 1;
    }

    return;
}

sub _update_current_base_limit {
    my $self = shift;

    $self->status_message("Updating current base limit...");

    my $current_base_limit = $self->_current_base_limit;
    my $metrics_file = $self->_metrics_file;
    if ( defined $current_base_limit and not -s $metrics_file ) {
        $self->error_message("Current base limit is set, but there is not metrics file ($metrics_file) to be able to update it.");
        return;
    }

    # get coverage
    $self->status_message("Getting coverage from metrics file: $metrics_file");
    my  $fh;
    eval {
        $fh = Genome::Utility::FileSystem->open_file_for_reading($metrics_file);
    };
    unless ( $fh ) {
        $self->error_message("Cannot open coverage metrics file ($metrics_file): $@");
        return;
    }
    my $coverage;
    while ( my $line = $fh->getline ) {
        if ( $line =~ /^bases=(\d+)/ ) {
            $coverage = $1;
            last;
        }
    }
    if ( not defined $coverage ) {
        $self->error_message("No coverage found in metrics file ($metrics_file)");
        return;
    }
    elsif ( $coverage <= 0 ) {
        $self->error_message("Coverage in metrics file ($metrics_file) is less than 0. This is impossible.");
        return;
    }
    $self->status_message("Got coverage: $coverage");

    # set new
    $current_base_limit -= $coverage;
    $self->_current_base_limit( $current_base_limit );
    $self->status_message("Setting new current base limit: $current_base_limit");
    $self->status_message('Updating current base limit OK');

    return 1;
}
#<>#

my %qual_types = (
    'Genome::InstrumentData::Solexa' => 'illumina',
    'Genome::InstrumentData::Imported' => 'sanger',
    #'Genome::Instrument::Data::454' => 'phred', # not ready
);
sub _process_instrument_data {
    my ($self, $instrument_data) = @_;

    # Inst data quality type
    my ($instrument_data_class) = $instrument_data->class;
    my $qual_type = $qual_types{$instrument_data_class};
    unless ( $qual_type ) {
        $self->error_message("Unsupported instrument data class ($instrument_data_class).");
        return;
    }

    $self->status_message('Processing: '.join(' ', $instrument_data_class, $instrument_data->id, $qual_type) );

    # Inst data files
    my @input_files = $self->_fastq_files_from_solexa($instrument_data)
        or return;

    # Fast qual command
    my $read_processor = $self->processing_profile->read_processor;
    my $base_limit = $self->_current_base_limit;
    my $fast_qual_class;
    my %fast_qual_params = (
        input => \@input_files,
        output => [ $self->build->assembler_input_files ],
        type_in => $qual_type,
        type_out => $qual_type, # TODO make sure this is sanger
    );
    if ( not defined $read_processor and not defined $base_limit ) {
        # If no read processor or base limt - just rename
        $fast_qual_class = 'Genome::Model::Tools::FastQual::Rename';
        $fast_qual_params{matches} = 'qr{#.*/1$}=.b1,qr{#.*/2$}=.g1';
    }
    else {
        # Got multiple commands, use pipe
        $fast_qual_class = 'Genome::Model::Tools::FastQual::Pipe';
        my @commands = ( 'rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1' ); # rename

        if ( defined $base_limit ) { # coverage limit by bases
            unshift @commands, 'limit by-coverage --bases '.$base_limit;
            $fast_qual_params{metrics_file} = $self->_metrics_file;
        }

        if ( defined $read_processor ) { # read processor from pp
            unshift @commands, $read_processor;
        }

        $fast_qual_params{commands} = join(' | ', @commands);
    }

    # Create and execute
    $self->status_message('Fast qual class: '.$fast_qual_class);
    $self->status_message('Fast qual params: '.Dumper(\%fast_qual_params));
    my $fast_qual_command = $fast_qual_class->create(%fast_qual_params);
    if ( not defined $fast_qual_command ) {
        $self->error_message("Cannot create fast qual command.");
        return;
    }
    my $rv = $fast_qual_command->execute;
    if ( not $rv ) {
        $self->error_message("Cannot execute fast qual command.");
        return;
    }
    $self->status_message('Execute OK');

    if ( defined $base_limit ) {
        $self->_update_current_base_limit
            or return;
    }

    return 1;
}
#<>#

#< Files From Instrument Data >#
sub _fastq_files_from_solexa {
    my ($self, $inst_data) = @_;

    $self->status_message("Getting fastq files from solexa instrument data ".$inst_data->id);

    my $archive_path = $inst_data->archive_path;
    $self->status_message("Verifying archive path: $archive_path");
    unless ( -s $archive_path ) {
        $self->error_message(
            "No archive path for instrument data (".$inst_data->id.")"
        );
        return;
    }
    $self->status_message("Archive path OK");

    # tar to tempdir
    my $tempdir = $self->_tempdir;
    my $inst_data_tempdir = $tempdir.'/'.$inst_data->id;
    $self->status_message("Creating temp dir: $inst_data_tempdir");
    Genome::Utility::FileSystem->create_directory($inst_data_tempdir)
        or die;
    $self->status_message("Temp dir OK");

    my $tar_cmd = "tar zxf $archive_path -C $inst_data_tempdir";
    $self->status_message("Running tar: $tar_cmd");
    unless ( Genome::Utility::FileSystem->shellcmd(cmd => $tar_cmd) ) {
        $self->error_message("Can't extract archive file $archive_path with command '$tar_cmd'");
        return;
    }
    $self->status_message("Tar OK");

    # glob files
    $self->status_message("Checking fastqs we're dumped...");
    my @fastq_files = glob $inst_data_tempdir .'/*';
    unless ( @fastq_files ) {
        $self->error_message("Extracted archive path ($archive_path), but no fastqs found.");
        return;
    }
    $self->status_message('Fastq files OK:'.join(", ", @fastq_files));

    return @fastq_files;
}
#<>#

1;

#$HeadURL$
#$Id$
