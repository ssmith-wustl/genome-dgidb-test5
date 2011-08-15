package Genome::Subject;

use strict;
use warnings;
use Genome;

class Genome::Subject {
    is => 'Genome::Notable',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        subject_id => {
            is => 'Number',
        },
    ],
    has => [
        subclass_name => {
            is => 'Text',
        },
        subject_type => {
            column_name => '',
            is_abstract => 1,
        },
    ],
    has_many_optional => [
        attributes => {
            is => 'Genome::SubjectAttribute',
            reverse_as => 'subject',
        },
    ],
    has_optional => [
        name => {
            is => 'Text',
        },
        common_name => {
            calculate_from => 'name',
            calculate => q{ return $name },
        },
        description => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'description' ],
        },
        nomenclature => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'nomenclature', nomenclature => 'WUGC' ],
        },
        disk_allocation => {
            is => 'Genome::Disk::Allocation', 
            calculate_from => [ 'subclass_name', 'id' ],
            calculate => q{
                my $disk_allocation = Genome::Disk::Allocation->get(
                    owner_class_name => $subclass_name,
                    owner_id => $id,
                );
                return $disk_allocation;
            },
        },
        data_directory => { 
            is => 'Text', 
            calculate_from => 'disk_allocation',
            calculate => q{
                return unless $disk_allocation;
                return $disk_allocation->absolute_path;
            },
        },
    ],
    table_name => 'GENOME_SUBJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Contains all information about a particular subject (sample, individual, taxon, etc)',
};

sub __display_name__ {
    my $self = shift;
    my $name = $self->name . ' ' if defined $self->name;
    $name .= '(' . $self->id . ')';
    return $name;
}
    
sub create {
    my ($class, %params) = @_;

    # This extra processing allows for someone to create a subject with properties that aren't listed in any of the
    # class definitions. Instead of having UR catch these extra and die, they are captured here and later turned into
    # subject attributes.
    my %extra;
    my @property_names = ('id', map { $_->property_name } ($class->__meta__->_legacy_properties, $class->__meta__->all_id_by_property_metas));
    #my @property_names = $class->__meta__->property_names;
    for my $param (sort keys %params) {
        unless (grep { $param eq $_ } @property_names) {
            $extra{$param} = delete $params{$param};
        }
    }

    my $self = $class->SUPER::create(%params);
    unless ($self) {
        Carp::confess "Could not create subject with params: " . Data::Dumper::Dumper(\%params);
    }

    for my $label (sort keys %extra) {
        my $attribute = Genome::SubjectAttribute->create(
            attribute_label => $label,
            attribute_value => $extra{$label},
            subject_id => $self->subject_id,
        );
        unless ($attribute) {
            $self->error_message("Could not create attribute $label => " . $extra{$label} . " for subject " . $self->subect_id);
            $self->delete;
        }
    }

    return $self;
}

sub delete {
    my $self = shift;

    # TODO Need to make sure this subject isn't used anywhere prior to deleting, though this should be done in each specific subclass

    my @attributes = $self->attributes;
    for my $attribute (@attributes) {
        Carp::confess "Could not delete attribute " . $attribute->attribute_label . " for subject " . $self->id unless $attribute->delete;
    }

    my $allocation = $self->disk_allocation;
    $allocation->deallocate_on_commit if $allocation;

    return $self->SUPER::delete;
}

sub add_file {
    my ($self, $file) = @_;

    $self->status_message('Add file to '. $self->__display_name__);

    Carp::confess('No file to add') if not $file;
    my $size = -s $file;
    Carp::confess("File ($file) to add does not have any size") if not $size;
    my $base_name = File::Basename::basename($file);
    Carp::confess("Could not get basename for file ($file)") if not $base_name;
    
    my $disk_allocation = $self->disk_allocation;
    if ( not $disk_allocation ) {
        # Create
        $disk_allocation = Genome::Disk::Allocation->allocate(
            disk_group_name => 'info_genome_models',
            allocation_path => '/model_data/'.$self->id,
            kilobytes_requested => $size,
            owner_class_name => $self->class,
            owner_id => $self->id
        );
        if ( not $disk_allocation ) {
            Carp::confess('Failed to create disk allocation to add file');
        }
    }
    else { 
        # Make sure we don't overwrite
        if ( grep { $base_name eq $_ } map { File::Basename::basename($_) } glob($disk_allocation->absolute_path.'/*') ) {
            Carp::confess("File ($base_name) to add already exists in path (".$disk_allocation->absolute_path.")");
        }
        # Reallocate w/ move to accomodate the file
        my $realloc = eval{
            $disk_allocation->reallocate(
                kilobytes_requested => $disk_allocation->kilobytes_requested + $size,
                allow_reallocate_with_move => 1,
            );
        };
        if ( not $realloc ) {
            Carp::confess("Cannot reallocate (".$disk_allocation->id.") to accomadate the file ($file)");
        }
    }

    my $absolute_path = $disk_allocation->absolute_path;
    if ( not -d $absolute_path ){
        Carp::confess('Absolute path does not exist for disk allocation: '.$disk_allocation->id);
    }
    my $to = $absolute_path.'/'.$base_name;
    
    $self->status_message("Copy $file to $to");
    my $copy = File::Copy::copy($file, $to);
    if ( not $copy ) {
        Carp::confess('Copy of file failed');
    }

    my $new_size = -s $to;
    if ( $new_size != $size ) {
        Carp::confess("Copy of file ($file) succeeded, but file ($to) has different size.");
    }

    $self->status_message('Add file...OK');

    return 1;
}

sub get_files {
    my $self = shift;

    my $disk_allocation = $self->disk_allocation;
    return if not $disk_allocation;

    return glob($disk_allocation->absolute_path.'/*');
}

1;

