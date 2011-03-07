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
        _report => {
            is_transient => 1,
            doc => 'Stores report text',
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

sub objects_to_sync {
    return (
        'Genome::InstrumentData::454' => 'Genome::Site::WUGC::InstrumentData::454',
        'Genome::InstrumentData::Sanger' => 'Genome::Site::WUGC::InstrumentData::Sanger',
        'Genome::InstrumentData::Solexa' => 'Genome::Site::WUGC::InstrumentData::Solexa',
        'Genome::Individual' => 'Genome::Site::WUGC::Individual',
        'Genome::PopulationGroup' => 'Genome::Site::WUGC::PopulationGroup',
        'Genome::Taxon' => 'Genome::Site::WUGC::Taxon',
        'Genome::Sample' => 'Genome::Site::WUGC::Sample',
    );
}

# Every time a new object is made, it'll check if there's a method like this
# for that type, which will contain special handling code.
sub genome_populationgroup {
    my ($self, $old_object) = @_;
    my @member_ids = map { $_->id } $old_object->members;
    my %extra;
    $extra{member_ids} = \@member_ids;
    return %extra;
}

sub genome_sample {
    my ($self, $old_object) = @_;
    my @attributes = $old_object->attributes;
    my %extra;
    for my $attribute (@attributes) {
        $extra{$attribute->name} = $attribute->value;
    }

    # Unload UR::Object::View::Aspect, which for whatever reason accumulates during sync
    UR::Object::View::Aspect->unload;

    return %extra;
}

sub genome_instrumentdata_solexa { shift->genome_instrumentdata(shift) };
sub genome_instrumentdata_454 { shift->genome_instrumentdata(shift) };
sub genome_instrumentdata_sanger { shift->genome_instrumentdata(shift) };
sub genome_instrumentdata {
    my ($self, $old_object) = @_;
    my @attributes = $old_object->attributes;
    my %extra;
    for my $attribute (@attributes) {
        $extra{$attribute->name} = $attribute->value;
    }

    # Subclass name should be Genome::InstrumentData::*, not Genome::Site::WUGC::InstrumentData*
    my $subclass_name = $old_object->subclass_name;
    $subclass_name =~ s/Site::WUGC:://;
    $extra{subclass_name} = $subclass_name;

    return %extra;
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

        $self->status_message("\n\nSyncing $new_type and $old_type");

        my $new_meta = $new_type->__meta__;
        confess "Could not get meta object for $new_type" unless $new_meta;
        my $old_meta = $old_type->__meta__;
        confess "Could not get meta object for $old_type" unless $old_meta;

        # Get attributes for old and new class. Not gonna worry about checking the attributes, since new subjects
        # can handle any attribute (per Genome::SubjectAttribute). There may be failures if old objects
        # are being created, but these can be addressed on a per-case basis
        $self->{_current_new_attributes} = $self->get_class_attributes($new_meta);
        confess "Could not get attributes for $new_type" unless defined $self->{_current_new_attributes};
        $self->{_current_old_attributes} = $self->get_class_attributes($old_meta);
        confess "Could not get attributes for $old_type" unless defined $self->{_current_old_attributes};

        my $new_iterator = $new_type->create_iterator;
        my $old_iterator = $old_type->create_iterator;
        
        # This whole scheme assumes that the corresponding rows between the two tables
        # have the same ID. If this isn't true, it'll be much harder to generalize this
        my $new_object = $new_iterator->next;
        my $old_object = $old_iterator->next;
        while ($new_object or $old_object) {
            $objects_seen_count++;
            if ($objects_seen_count != 0 and $objects_seen_count % 10000 == 0) {
                $self->status_message("Looked at $objects_seen_count objects!");
            }

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
                if ($new_id eq $old_id) {
                    $new_object = $new_iterator->next;
                    $old_object = $old_iterator->next;
                }
                # If new ID is less than old ID, then we are missing an old object (since the
                # iterator skipped over several
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
        $self->status_message("Done syncing $new_type and $old_type");
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
    my %attributes;
    map { $attributes{$_} = $original_object->{$_} if defined $original_object->{$_} } @$new_object_attributes;

    # Some classes may require special handling... see if this class has such a method and execute it
    my $method_name = lc $new_object_class;
    $method_name =~ s/::/_/g;
    my %extra_params;
    if ($self->can($method_name)) {
        %extra_params = $self->$method_name($original_object);
    }

    my $object = $new_object_class->create(%attributes, %extra_params);
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id unless $object;

    $created_object_count++;
    if ($created_object_count > 0 and $created_object_count % 1000 == 0) {
        $self->status_message("Created $created_object_count objects!");
        # Committing periodically to prevent too much progress from being lost
        unless (UR::Context->commit) {
            confess 'Could not commit object type ' . $object->class . ' with id ' . $object->id . '!';
        }
    }

    return 1;
}

1;

