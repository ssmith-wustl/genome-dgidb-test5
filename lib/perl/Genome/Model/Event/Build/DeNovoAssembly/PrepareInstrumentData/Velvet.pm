package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Temp;
require IPC::Run;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
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
        $self->{_tempdir} = File::Temp::tempdir(
            DIR => $self->build->data_directory,
            CLEANUP => 1,
        );
        Genome::Utility::FileSystem->validate_existing_directory( $self->{_tempdir} )
            or die;
    }
    
    return $self->{_tempdir};
}

sub _coverage_metrics_file { 
    return $_[0]->_tempdir.'/coverage.metrics';
}

sub execute {
    my $self = shift;

    $self->status_message('Preparing instrument data velvet...');

    $self->status_message('Checking instrument data...');
    my @instrument_data = $self->build->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->build->description);
        return;
    }
    $self->status_message('Instrument data OK');

    $self->_setup_read_processor
        or return;

    my $sequencing_platform = $self->processing_profile->sequencing_platform;
    my $file_method = '_fastq_files_from_'.$sequencing_platform;
    INST_DATA: for my $inst_data ( @instrument_data ) {
        my @files = $self->$file_method($inst_data)
            or return; # error in sub
        $self->_run_read_processor_for_files(@files)
            or return;
        if ( defined $self->_current_base_limit and $self->_current_base_limit <= 0 ) {
            # exceeded coverage
            $self->status_message('Exceeded coverage, stop adding to collated fastq');
            last INST_DATA;
        }
    }

    $self->status_message('Preparing instrument data velvet OK');

    return 1;
}

sub _setup_read_processor {
    my $self = shift;

    $self->status_message("Read processor setup...");

    my $read_processor = $self->build->processing_profile->read_processor || '';
    my $base_limit = $self->build->calculate_base_limit_from_coverage;
    my $rename_cmd = 'gmt fast-qual rename --matches qr{#.*/1$}=.b1,qr{#.*/2$}=.g1';
    if ( not $read_processor and not defined $base_limit ) {
        # rename (will collate, too)
        my $command = $rename_cmd.' --input %s --output %s --type-in illumina';
        $self->status_message("No read processor or base limit");
        $self->status_message($command);
        $self->status_message("Read processor setup OK");
        return $self->_read_processor_pipe_command($command);
    }

    # split read processors
    my @read_processors = split(/\|/, $read_processor);

    # add limit by base coverage 
    if ( $base_limit ) { 
        $self->status_message("Have base limit: $base_limit");
        push @read_processors, 'limit by-coverage --bases %s --metrics-file '.$self->_coverage_metrics_file;
        $self->_current_base_limit($base_limit);
    }

    # convert read processors to commands
    my @commands = (
        'gmt fast-qual '.$read_processors[0].' --input %s --output PIPE --type-in illumina'
    );
    for ( my $i = 1; $i <= $#read_processors; $i++ ) {
        push @commands, 'gmt fast-qual '.$read_processors[$i].' --input PIPE --output PIPE';
    }

    # rename to pcap (last)
    push @commands, $rename_cmd.' --input PIPE --output %s';

    my $command = join(' | ', @commands );
    $self->_read_processor_pipe_command($command);
    $self->status_message($command);
    $self->status_message("Read processor setup OK");

    return $command;
}

sub _run_read_processor_for_files {
    my ($self, @files) = @_;

    $self->status_message("Run read processor for files...");

    # Cmd params - in array to work w/ sprintf
    # input
    my @cmd_params = join(',', @files);

    # base limit
    my $current_base_limit = $self->_current_base_limit;
    push @cmd_params, $current_base_limit if defined $current_base_limit;

    # output 
    push @cmd_params, $self->build->collated_fastq_file,

    # execute command
    my $cmd_template = $self->_read_processor_pipe_command;
    my $cmd = sprintf($cmd_template, @cmd_params);

    $self->status_message('Run read processor command');
    $self->status_message($cmd);
    unless ( IPC::Run::run($cmd) ) {
        $self->error_message("Failed to run read processor command!");
        return;
    }
    $self->status_message('Run read processor command OK');

    # base limit
    if ( not defined $current_base_limit ) {
        return 1; # ok, continue no limit by bases
    }

    $self->_update_current_base_limit
        or return;

    return 1;
}

sub _update_current_base_limit {
    my $self = shift;

    $self->status_message("Updating current base limit...");

    my $current_base_limit = $self->_current_base_limit;
    my $coverage_metrics_file = $self->_coverage_metrics_file;
    if ( defined $current_base_limit and not -s $coverage_metrics_file ) {
        $self->error_message("Current base limit is set, but there is not metrics file ($coverage_metrics_file) to be able to update it.");
        return;
    }

    # get coverage
    $self->status_message("Getting coverage from metrics file: $coverage_metrics_file");
    my  $fh;
    eval {
        $fh = Genome::Utility::FileSystem->open_file_for_reading($coverage_metrics_file);
    };
    unless ( $fh ) {
        $self->error_message("Cannot open coverage metrics file ($coverage_metrics_file): $@");
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
        $self->error_message("No coverage found in metrics file ($coverage_metrics_file)");
        return;
    }
    elsif ( $coverage <= 0 ) {
        $self->error_message("Coverage in metrics file ($coverage_metrics_file) is less than 0. This is impossible.");
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
    $self->status_message( join("\n", @fastq_files) );
    $self->status_message("Fastq files OK");

    return @fastq_files;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.pm $
#$Id: PrepareInstrumentData.pm 45247 2009-03-31 18:33:23Z ebelter $
