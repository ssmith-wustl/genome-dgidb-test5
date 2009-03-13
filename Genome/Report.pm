package Genome::Report;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Storable;

class Genome::Report {
    is => 'UR::Object',
    id_by => [qw/ name parent_directory /],
    has => [
    name => { 
        is => 'Text',
        doc => 'Name of the report',
    },
    parent_directory => {
        is => 'Text',
        doc => 'Parent directory for the report',
    },
    ],
};

#< Directory >#
sub directory {
    return $_[0]->get_directory_for_parent_directory_and_name(
        name => $_[0]->name,
        parent_directory => $_[0]->parent_directory,
    );
}

sub get_directory_for_parent_directory_and_name {
    my ($class, %params) = @_;

    return $params{parent_directory}.'/'.$class->name_to_subdirectory($params{name});
}

sub get_parent_directory_and_name_from_directory {
    my ($class, $directory) = @_;

    my ($sub_directory, $parent_directory) = File::Basename::fileparse($directory);
    
    return (
        name => $class->subdirectory_to_name($sub_directory),
        parent_directory => $parent_directory,
    );
}

#< Data >#
sub get_data { 
    return $_[0]->{_data};
}

sub set_data { 
    my ($self, $data) = @_;

    $self->validate_data($data)
        or return;
    
    return $self->{_data} = $data;
}

sub validate_data {
    my ($self, $data) = @_;

    unless ( defined $data ) {
        $self->error_message("No data given to 'set_data'");
        return;
    }
    
    unless ( ref($data) eq 'HASH' ) {
        $self->error_message("Data sent to 'set_data' must be a hash ref");
        return;
    }

    $data->{date} = 'Unknown' unless $data->{date};

    for my $req (qw/ description /) {
        unless ( defined $data->{$req} ) {
            $self->error_message("Data sent to 'set_data', does not have required key ($req)");
            return;
        }
    }
    
    return 1;
}

sub generate_data {
    my $self = shift;

    unless ( $self->can('_generate_data') ) {
        confess "This report class does not implement '_generate_data' method.  Please correct.";
    }

    if ( $self->get_data ) { # allow regeneration?
        $self->error_message("Data has already been generated");
        return;
    }

    my $data = $self->_generate_data;
    unless ( $data ) { 
        $self->error_message("No data was generated");
        return;
    }

    print Dumper($data);
    
    $data->{date} = UR::Time->now;
    $data->{params} = $self->get_params_for_generation;

    return $self->set_data($data);
}

#< Get/Create >#
sub get {
    my $class = shift;
    return $class->get_or_create(@_);
}

sub create {
    my $class = shift;
    return $class->get_or_create(@_);
}

sub get_reports_in_parent_directory {
    my ($class, $parent_directory) = @_;

    Genome::Utility::FileSystem->validate_directory_for_read_access($parent_directory)
        or return;

    my @reports;
    for my $directory ( glob($parent_directory.'/*') ) {
        next unless -d $directory;
        push @reports, $class->get_or_create(
            $class->get_parent_directory_and_name_from_directory($directory),
        )
            or next; # TODO or return/die?
    }

    return @reports;
}

sub get_or_create {
    my ($class, %params) = @_;

    if ( $params{data} ) {
        $class->error_message("Cannot get or create with param data.  Please use 'set_data' after get or create.");
        return;
    }

    for my $prop (qw/ name parent_directory /) {
        unless ( defined $params{$prop} ) {
            $class->error_message("Property ($prop) is required");
            print "Property ($prop) is required\n";
            return;
        }
    }

    Genome::Utility::FileSystem->validate_directory_for_read_write_access($params{parent_directory})
        or return;

    # get from cache
    my $self = $class->SUPER::get(%params);

    # Create w/ properties file - really a get, but the create adds the object to the cache
    unless ( $self ) {
        $self = $class->_create_from_properties_file(%params);
    }

    # Create a fresh report
    unless ( $self ) {
        $self = $class->SUPER::create(%params);
    }

    return $self;
}

sub _create_from_properties_file {
    my ($class, %params) = @_;

    my $directory = $class->get_directory_for_parent_directory_and_name(%params);

    return unless $class->property_file_exists($directory);

    my $properties = $class->retrieve_report_properties($directory)
        or return; # ERROR?

    my $sub_class = delete $properties->{class};
    my $data = delete $properties->{data};

    if ( %$properties ) { # should be empty
        #$class->error_message("Left over properties in report store file: ".keys(%$properties));
        #confess;
    }

    my $self = $sub_class->SUPER::create(%params)
        or return;

    if ( defined $data ) { 
        # set data and params
        unless ( $self->set_data($data) ) {
            $self->delete;
            return;
        }
        if ( $data->{params} ) {
            for my $key ( keys %{$data->{params}} ) {
                $self->$key( $data->{params}->{$key} );
            }
        }
    }

    return $self;
}

#< Storing Object Properties >#
sub property_file {
    my ($self, $directory) = @_;

    return $directory.'/properties.stor';
}

sub property_file_exists {
    my ($self, $directory) = @_;

    return 1 if -s $self->property_file($directory);
}

sub name_to_subdirectory {
    return join('_', map { lc } split(' ', $_[1]));
}

sub subdirectory_to_name {
    return join(' ', map { ucfirst } split('_', $_[1]));
}

sub save {
    my $self = shift;

    unless ( $self->get_data ) {
        $self->error_message('No data was set or generated to save');
        return;
    }

    Genome::Utility::FileSystem->validate_directory_for_write_access( $self->parent_directory )
        or return;

    my $directory = $self->directory;
    Genome::Utility::FileSystem->create_directory($directory)
        or return;
    my $file = $self->property_file($directory);
    unlink $file if -e $file;
    
    my %info = (
        class => $self->class,
        data => $self->get_data,
    );

    unless ( store(\%info, $file) ) {
        $self->error_message("Could not stroe report properties to file ($file): $!");
        return;
    }

    return 1;
}

sub retrieve_report_properties {
    my ($class, $directory) = @_;

    my $file = $class->property_file($directory);
    Genome::Utility::FileSystem->validate_file_for_reading($file)
        or return;
    
    my $props = retrieve($file);

    unless ( $props ) {
        $class->error_message("Could not retrieve report properties from file ($file): $!");
        return;
    }

    return $props;
}

sub get_params_for_generation {
    my $self = shift;

    my %params;
    for my $property ( $self->get_class_object->get_all_property_objects ) {
        next if $property->via or $property->id_by;
        next unless $property->class_name->isa('Genome::Report');
        next if $property->class_name eq 'Genome::Report';
        my $property_name = $property->property_name;
        #print Dumper($property_name);
        $params{$property_name} = $self->$property_name;
    }

    return \%params;
}

#< Report Data >#
# TODO maybe...one day use XML to serialize, then change these methods to convert the data
sub get_brief_output {
    return $_[0]->get_description;
    # FYI this was generating if file didn't exist
}

sub get_detail_output {
    return $_[0]->get_as_html;
    # FYI this was generating if file didn't exist
}

sub get_description {
    my $self = shift;

    return $self->data->{description};
}

sub get_html {
    my $self = shift;

    return $self->data->{html};
}

sub get_csv {
    my $self = shift;

    return $self->data->{csv};
}

sub get_xml {
    my $self = shift;

    return $self->data->{xml};
}

1;

#$HeadURL$
#$Id$
