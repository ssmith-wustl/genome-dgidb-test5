package Genome::Site::WUGC::Synchronize::Subject;

use strict;
use warnings;
use Genome;
use Carp 'confess';

my $low = 50_000;
my $high = 400_000;
UR::Context->object_cache_size_highwater($high);
UR::Context->object_cache_size_lowwater($low);

class Genome::Site::WUGC::Synchronize::Subject {
    is => 'Genome::Command::Base',
    has => [
        direction => {
            is => 'Text',
            valid_values => ['forward', 'reverse', 'both'],
            default_value => 'forward',
            doc => 'Which way to synchronize.  Forward imports data from LIMS tables to Apipe tables, ' .
                'reverse imports data from Apipe to LIMS, and both is self-explanatory',
        },
        report => {
            is => 'Boolean',
            default_value => 1,
            doc => 'Reports objects missing critical information',
        },
    ],
    has_optional => [
        _forward => {
            calculate_from => ['direction'],
            calculate => q{ return $direction eq 'forward' or $direction eq 'both' },
        },
        _reverse => {
            calculate_from => ['direction'],
            calculate => q{ return $direction eq 'reverse' or $direction eq 'both' },
        },
        _old_attributes => {
            is_transient => 1,
            doc => 'Stores attributes of old type currently being synced',
        },
        _new_attributes => {
            is_transient => 1,
            doc => 'Stores attributes of new type currently being synced',
        },
    ],
};

# Maps new classes to old classes. Abstract classes should not be included here because 
# it can lead to some attributes not being copied over.
sub objects_to_sync {
    return (
        'Genome::InstrumentData::454' => 'Genome::Site::WUGC::InstrumentData::454',
        #'Genome::InstrumentData::Sanger' => 'Genome::Site::WUGC::InstrumentData::Sanger',
        'Genome::InstrumentData::Solexa' => 'Genome::Site::WUGC::InstrumentData::Solexa',
        'Genome::Individual' => 'Genome::Site::WUGC::Individual',
        'Genome::PopulationGroup' => 'Genome::Site::WUGC::PopulationGroup',
        'Genome::Taxon' => 'Genome::Site::WUGC::Taxon',
        'Genome::Sample' => 'Genome::Site::WUGC::Sample',
    );
}


my $created_object_count = 0;
sub execute {
    my $self = shift;

    my $objects_seen_count = 0;
    my %types = $self->objects_to_sync;
    for my $new_type (sort keys %types) {
        my $old_type = $types{$new_type};
        $created_object_count = 0;
        $objects_seen_count = 0;

        $self->status_message("\nSyncing $new_type and $old_type");

        my $new_meta = $new_type->__meta__;
        confess "Could not get meta object for $new_type" unless $new_meta;
        my $old_meta = $old_type->__meta__;
        confess "Could not get meta object for $old_type" unless $old_meta;

        # Get attributes for old and new class. Not gonna worry about checking the attributes, since new objects
        # can handle any attribute). There may be failures if old objects are being created, but these can 
        # be addressed on a per-case basis
        $self->{_current_new_attributes} = $self->get_class_attributes($new_meta);
        confess "Could not get attributes for $new_type" unless defined $self->{_current_new_attributes};
        $self->{_current_old_attributes} = $self->get_class_attributes($old_meta);
        confess "Could not get attributes for $old_type" unless defined $self->{_current_old_attributes};

        $self->status_message("Creating iterators...");
        my $new_iterator = $new_type->create_iterator;
        my $old_iterator = $old_type->create_iterator;
        
        # This whole scheme assumes that the corresponding rows between the two tables
        # have the same ID. If this isn't true, it'll be much harder to generalize this
        $self->status_message("Iterating over all objects and copying as needed");
        my $new_object = $new_iterator->next;
        my $old_object = $old_iterator->next;
        while ($new_object or $old_object) {
            $objects_seen_count++;

            print STDERR "Syncing $new_type and $old_type, seen $objects_seen_count, copied $created_object_count\r";

            # Old iterator exhausted
            if ($new_object and not $old_object) {
                if ($self->_reverse) {
                    $self->copy_object($new_object, $old_type, $self->{_current_old_attributes});
                    $new_object = $new_iterator->next;
                }
                else {
                    last;
                }
            }
            # New iterator exhausted
            elsif ($old_object and not $new_object) {
                if ($self->_forward) {
                    $self->copy_object($old_object, $new_type, $self->{_current_new_attributes});
                    $old_object = $old_iterator->next;
                }
                else {
                    last;
                }
            }
            # Compare IDs to determine what object needs created here
            else {
                my $new_id = $new_object->id;
                my $old_id = $old_object->id;
                # If IDs are equal, iterate both old and new and continue
                # FIXME This assumes numeric IDs, which is not true for sanger instrument data
                if ($new_id eq $old_id) {
                    $new_object = $new_iterator->next;
                    $old_object = $old_iterator->next;
                }
                # If new ID is less than old ID, then we are missing an old object (since the iterator skipped over several)
                elsif ($new_id < $old_id) {
                    if ($self->_reverse) {
                        $self->copy_object($new_object, $old_type, $self->{_current_old_attributes});
                    }
                    $new_object = $new_iterator->next;
                }
                else {
                    if ($self->_forward) {
                        $self->copy_object($old_object, $new_type, $self->{_current_new_attributes});
                    }
                    $old_object = $old_iterator->next;
                }
            }
        }

        UR::Context->commit;
        $self->status_message("\nDone syncing $new_type and $old_type, looked at $objects_seen_count objects and created $created_object_count.");
    }

    return 1;
}

sub get_class_attributes {
    my ($self, $meta) = @_;
    my @attributes = grep { $_ !~ /^_/ } map { $_->property_name } $meta->properties;
    return \@attributes;
}

sub copy_object {
    my ($self, $original_object, $new_object_class, $new_object_attributes) = @_;
    
    my $method_base = lc $new_object_class;
    $method_base =~ s/::/_/g;

    # Some objects require that certain criteria be met before a new object is created
    my $valid_method_name = $method_base . '_is_valid';
    if ($self->can($valid_method_name)) {
        return 1 unless $self->$valid_method_name($original_object);
    }

    # Some classes may require extra parameters be passed to create
    my $extra_method_name = $method_base . '_extra_params';
    my %extra_params;
    if ($self->can($extra_method_name)) {
        %extra_params = $self->$extra_method_name($original_object);
    }

    my %attributes;
    map { $attributes{$_} = $original_object->{$_} if defined $original_object->{$_} } @$new_object_attributes;

    my $object = eval { $new_object_class->create(%attributes, id => $original_object->id, %extra_params) };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id unless $object;

    $created_object_count++;
    if ($created_object_count % 1000 == 0) {
        # Committing periodically to prevent too much progress from being lost and allow cache to be pruned
        unless (UR::Context->commit) {
            confess "Could not commit created objects of type $new_object_class!";
        }
    }

    return 1;
}

# These methods check if the original object is valid. If not, a new object is not created
sub genome_instrumentdata_sanger_is_valid {
    my ($self, $old_object) = @_;
    return 0 unless defined $old_object->library_id or defined $old_object->library_name or defined $old_object->library_summary_id;

    my %params;
    if (defined $old_object->library_id) {
        $params{id} = $old_object->library_id;
    }
    elsif (defined $old_object->library_name) {
        $params{name} = $old_object->library_name;
    }
    else {
        $params{id} = $old_object->library_summary_id;
    }
    
    my $library = Genome::Library->get(%params);
    return 0 unless $library;

    return 1;
}

# These methods add extra parameters to object creation, depending on class
sub genome_populationgroup_extra_params {
    my ($self, $old_object) = @_;
    my @member_ids = map { $_->id } $old_object->members;
    my %extra;
    $extra{member_ids} = \@member_ids;
    return %extra;
}

sub genome_sample_extra_params {
    my ($self, $old_object) = @_;
    my @attributes = $old_object->attributes;
    my %extra;
    for my $attribute (@attributes) {
        $extra{$attribute->name} = $attribute->value;
    }

    # Unload UR::Object::View::Aspect, which for whatever reason accumulates during sync and
    # can cause the cache to be filled with unprunable objects
    UR::Object::View::Aspect->unload;

    return %extra;
}

sub genome_instrumentdata_sanger_extra_params { 
    my ($self, $old_object) = @_;
    my %extra = $self->genome_instrumentdata_extra_params($old_object);
    unless (exists $extra{library_id}) {
        my $library;
        if (defined $old_object->library_name) {
            $library = Genome::Library->get(name => $old_object->library_name);
        }
        elsif (defined $old_object->library_summary_id) {
            $library = Genome::Library->get($old_object->library_summary_id);
        }
        confess 'Could not determine library for sanger instrument data ' . $old_object->id unless $library;

        $extra{library_name} = $library->name;
        $extra{library_id} = $library->id;
    }
    return %extra;
}

sub genome_instrumentdata_extra_params {
    my ($self, $old_object) = @_;
    my @attributes = $old_object->attributes;
    my %extra;
    for my $attribute (@attributes) {
        # If a sample parameter is included in create, UR will attempt to go from sample to library (via
        # all the indirect properties defined on instrument data). Since a sample has multiple libraries,
        # trying to resolve a single library will fail. Since library id is included for all instrument data,
        # there's no need to include sample data.
        next if grep { $attribute->property_name eq $_ } qw/ sample_name sample_id /;
        $extra{$attribute->property_name} = $attribute->value;
    }

    # Subclass name should be Genome::InstrumentData::*, not Genome::Site::WUGC::InstrumentData*
    my $subclass_name = $old_object->subclass_name;
    $subclass_name =~ s/Site::WUGC:://;
    $extra{subclass_name} = $subclass_name;

    return %extra;
}

sub genome_instrumentdata_solexa_extra_params { shift->genome_instrumentdata_extra_params(shift) };
sub genome_instrumentdata_454_extra_params { shift->genome_instrumentdata_extra_params(shift) };

1;

