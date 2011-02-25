package Genome::Site::WUGC::Finishing::Project::ProcessFactory;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use File::Basename;
use Finfo::CommandLineOptions;
use Genome::Site::WUGC::Finishing::Project::Factory;
use Genome::Site::WUGC::Finishing::Project::Namer;
use Genome::Site::WUGC::Finishing::Project::Reader;
use Genome::Site::WUGC::Finishing::Project::Writer;
use PP::LSF;

my %process :name(process:r)
    :type(in_list)
    :options([ __PACKAGE__->valid_processes ])
    :clo('process=s')
    :desc('The process to execute: ' . join(',', __PACKAGE__->valid_processes));
my %options :name(options:o) :type(non_empty_hashref);

# Process and Steps
sub valid_processes
{
    return keys %{ ( _processes_and_classes() ) };
}

sub _process_classes
{
    my $self = shift;
    
    return $self->_processes_and_classes->{ $self->process };
}

sub _processes_and_classes 
{
    return
    {
        checkout => [qw/ Genome::Site::WUGC::Finishing::Project::Checkout /], 
        convert => [qw/ Genome::Site::WUGC::Finishing::Project::Converter Genome::Site::WUGC::Finishing::Project::Namer /],
        convert_from_agp => [qw/ Genome::Site::WUGC::Finishing::Project::AGPConverter Genome::Site::WUGC::Finishing::Project::Namer /],
        create  => [qw/ Genome::Site::WUGC::Finishing::Project::Reader Genome::Site::WUGC::Finishing::Project::Factory /],
        split_sc  => [qw/ Genome::Site::WUGC::Finishing::Project::SuperContigSplitter Genome::Site::WUGC::Finishing::Project::Namer /],
        split_acefile => [qw/ Genome::Site::WUGC::Finishing::Project::AcefileSplitter Genome::Site::WUGC::Finishing::Project::Namer /],
    };
}

# Execute
sub execute
{
    my $self = shift;

    $self->info_msg( sprintf('Processing options for process (%s)', $self->process) );
    
    my $method = ( $self->options ) 
    ? '_create_steps_for_' . $self->process
    : '_process_command_line_args';

    return $self->$method;
}

sub _process_command_line_args : PRIVATE
{
    my $self = shift;

    $self->info_msg('Processing command line args');
    
    my $clo = Finfo::CommandLineOptions->new
    (
        classes => $self->_process_classes,
        add_q => 1,
        header_msg => "Usage for '$0 " . $self->process . "'",
    )
        or return;

    my $opts = $clo->get_options
        or return;

    $self->options($opts)
        or return;

    my $method = '_create_steps_for_' . $self->process;

    $self->info_msg('Creating steps');

    return $self->$method;
}

sub _validate_class_options : PRIVATE
{
    my $self = shift;

    $self->info_msg('Validating class options');

    foreach my $class ( @{ $self->_process_classes } )
    {
        return unless Finfo::Validate->validate
        (
            attr => "$class options",
            value => $self->options->{$class},
            type => 'non_empty_hashref',
            err_cb => $self,
        );
    }

    return 1;
}

# Split Acefiles
sub _create_steps_for_split_acefile
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    $self->options->{'Project::AcefileSplitter'}->{project_namer} = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    )
        or return;

    return Project::AcefileSplitter->new
    (
        %{ $self->options->{'Project::AcefileSplitter'} },
    );
}

# Convert
sub _create_steps_for_convert
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    my $proj_namer = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    );

    return Project::Converter->new
    (
        %{ $self->options->{'Project::Converter'} },
        project_namer => $proj_namer,
    );
}

sub _create_steps_for_convert_from_agp
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    $self->options->{'Project::AGPConverter'}->{project_namer} = Project::Namer->new
    (
        %{ $self->options->{'Project::Namer'} } 
    )
        or return;

    return Project::AGPConverter->new
    (
        %{ $self->options->{'Project::AGPConverter'} }
    );
}

# Create
sub _create_steps_for_create
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    my $reader =  Genome::Site::WUGC::Finishing::Project::Reader->new
    (
        io => %{ $self->_opts->{'Genome::Site::WUGC::Finishing::Project::Reader'} }
    );

    my $tmp_file = ".$$.tmp";
    Finfo::Validate->validate
    (
        attr => 'tmp dir',
        value => $tmp_file,
        type => 'output_file',
        err_cb => $self,
    );

    my $writer = Genome::Site::WUGC::Finishing::Project::Writer->new(io => $tmp_file)
        or return;

    return Project::Factory->new
    (
        %{ $self->options->{'Project::Factory'} },
        reader => $reader,
        writer => $writer,
    );
}

# Checkout 
sub _create_steps_for_checkout
{
    my $self = shift;

    $self->_validate_class_options
        or return;

    return Project::Checkout->new
    (
        %{ $self->options->{'Project::Checkout'} }
    );
}

1;

