package Genome::Report;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Storable;

class Genome::Report {
    is => 'UR::Object',
    has => [
    name => { 
        is => 'Text',
        doc => 'Name of the report',
    },
    ],
};

#< Get/Create >#
sub get { # no real 'get'...since storage is not synced
    confess "Cannot conventionally 'get' a report.  To get a stored report, use 'create_report_from_directory' or 'get_reports_in_parent_directory'\n";
}

sub create {
    my ($class, %params) = @_;

    my $data = delete $params{data};
    my $self = $class->SUPER::create(%params)
        or return;

    unless ( $self->name ) {
        $self->error_message("Need name to create");
        $self->delete;
        return;
    }

    unless ( $self->_set_data($data) ) {
        $self->delete;
        return;
    }

    return $self;
}

sub create_report_from_directory {
    my ($class, $directory) = @_;

    Genome::Utility::FileSystem->validate_directory_for_read_access($directory)
        or return;

    my %properties = $class->_retrieve_properties($directory)
        or return;

    return $class->create(%properties);
}

sub create_reports_from_parent_directory {
    my ($class, $parent_directory) = @_;

    Genome::Utility::FileSystem->validate_directory_for_read_access($parent_directory)
        or return;

    my @reports;
    for my $directory ( glob($parent_directory.'/*') ) {
        next unless -d $directory;
        my $report;
        eval {
            $report = $class->create_report_from_directory($directory)
        };
        next unless $report; # TODO or return/die?
        push @reports, $report;
    }

    return @reports;
}

#< Storing Object Properties >#
sub property_file {
    my ($class, $directory) = @_;

    confess "Need directory to get properties file name\n" unless $directory;
    
    return $directory.'/properties.stor';
}

sub name_to_subdirectory {
    return join('_', split(' ', $_[1]));
    #return join('_', map { lc } split(' ', $_[1]));
}

sub subdirectory_to_name {
    return join(' ', split('_', $_[1]));
    #return join(' ', map { ucfirst } split('_', $_[1]));
}

sub save {
    my ($self, $parent_directory) = @_;

    my $data = $self->get_data; # should not be necessary, data req'd for create
    unless ( $data ) {
        $self->error_message('No data was set or generated to save');
        return;
    }

    Genome::Utility::FileSystem->validate_directory_for_write_access($parent_directory)
        or return;

    my $directory = $parent_directory.'/'.$self->name_to_subdirectory( $self->name );
    Genome::Utility::FileSystem->create_directory($directory)
        or return;

    my $file = $self->property_file($directory)
        or return;
    Genome::Utility::FileSystem->validate_file_for_writing($file)
        or return;

    unless ( store($data, $file) ) {
        $self->error_message("Could not stroe report properties to file ($file): $!");
        return;
    }

    # Save a file for known data types
    my @known_data_types = (qw/ html csv /);
    for my $type ( @known_data_types ) {
        next unless exists $data->{$type};
        my $file = $directory.'/report.'.$type;
        unlink $file if -e $file;
        my $fh = Genome::Utility::FileSystem->open_file_for_writing($file)
            or confess;
        $fh->print( $data->{$type} );
        $fh->close;
    }

    return 1;
}

sub _retrieve_properties {
    my ($class, $directory) = @_;

    my $file = $class->property_file($directory);
    Genome::Utility::FileSystem->validate_file_for_reading($file)
        or return;
    
    my $data = retrieve($file);

    unless ( $data ) {
        $class->error_message("Could not retrieve report data from file ($file): $!");
        return;
    }

    my $name = $class->subdirectory_to_name( File::Basename::basename($directory) );
    unless ( $name ) {
        $class->error_message("Can't determine name from directory ($directory)");
        return;
    }
    
    return (
        name => $name,
        data => $data,
    );
}

#< Data >#
sub expected_data_keys {
    return (qw/ generator generator_params description /);
}

sub get_data { 
    return $_[0]->{_data};
}

sub _set_data { 
    my ($self, $data) = @_;

    $self->validate_data($data)
        or return;
    
    return $self->{_data} = $data;
}

sub validate_data {
    my ($self, $data) = @_;

    unless ( defined $data ) {
        $self->error_message("Data is not defined");
        return;
    }
    
    unless ( ref($data) eq 'HASH' ) {
        $self->error_message("Data is not a hash ref");
        return;
    }

    $data->{date} = UR::Time->now;

    for my $req ( $self->expected_data_keys ) {
        unless ( defined $data->{$req} ) {
            $self->error_message("Data does not have required key ($req)");
            return;
        }
    }
    
    return 1;
}

sub get_generator {
    return $_[0]->get_data->{generator};
}

sub get_generator_params {
    return $_[0]->get_data->{generator_params};
}

sub get_description {
    return $_[0]->get_data->{description};
}

sub get_html {
    return $_[0]->get_data->{html};
}

sub get_csv {
    return $_[0]->get_data->{csv};
}

sub get_xml {
    return $_[0]->get_data->{xml};
}

# Old data methods
sub get_brief_output {
    return $_[0]->get_description;
    # FYI this was generating if file didn't exist
}

sub get_detail_output {
    return $_[0]->get_as_html;
    # FYI this was generating if file didn't exist
}


1;

#$HeadURL$
#$Id$
