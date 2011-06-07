package Genome::Site::WUGC::Synchronize;

# TODO Lots of redundant code here that can be refactored away

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::Site::WUGC::Synchronize {
    is => 'Genome::Command::Base',
    has_optional => [
        report_file => {
            is => 'FilePath',
            doc => 'If provided, extra information is recorded in this file'
        },
        detailed_report => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, a detailed report is printed that lists all the objects that were copied/missing',
        },
        show_object_cache_summary => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, a summary of the contents of the UR object cache is occasionally printed, useful for debugging',
        },
        _report => {
            is_transient => 1,
            doc => 'Contains hashref to report generated by the execution of this tool',
        },
    ],
    doc => 'This command contains a mapping of old LIMS-based classes to new classes that use tables in ' .
        'the MG schema and determines if anything needs to be copied over',
};

# Maps old classes to new classes. Abstract classes should not be included here because 
# it can lead to some attributes not being copied over.
sub objects_to_sync {
    return (
        'Genome::Site::WUGC::InstrumentData::454' => 'Genome::InstrumentData::454',
        'Genome::Site::WUGC::InstrumentData::Sanger' => 'Genome::InstrumentData::Sanger',
        'Genome::Site::WUGC::InstrumentData::Solexa' => 'Genome::InstrumentData::Solexa',
        'Genome::Site::WUGC::InstrumentData::Imported' => 'Genome::InstrumentData::Imported',
        'Genome::Site::WUGC::Individual' => 'Genome::Individual',
        'Genome::Site::WUGC::PopulationGroup' => 'Genome::PopulationGroup',
        'Genome::Site::WUGC::Taxon' => 'Genome::Taxon',
        'Genome::Site::WUGC::Sample' => 'Genome::Sample',
        'Genome::Site::WUGC::Library' => 'Genome::Library',
    );
}

# Specifies the order in which classes should be synced
sub sync_order {
    return qw/ 
        Genome::Site::WUGC::Taxon
        Genome::Site::WUGC::Individual
        Genome::Site::WUGC::PopulationGroup
        Genome::Site::WUGC::Sample
        Genome::Site::WUGC::Library
        Genome::Site::WUGC::InstrumentData::Solexa
        Genome::Site::WUGC::InstrumentData::Imported
        Genome::Site::WUGC::InstrumentData::454
    /;

    # FIXME Currently not syncing sanger data due to a bug, needs to be fixed
    #Genome::Site::WUGC::InstrumentData::Sanger
}

# For each pair of classes above, determine which objects exist in both the old and new schemas and
# copy the old objects into the new schema and report the new objects that don't exist in the old schema
sub execute {
    my $self = shift;

    # Stores copied and missing IDs for each type
    my %report;
    
    # Maps new classes with old classes
    my %types = $self->objects_to_sync;

    for my $old_type ($self->sync_order) {
        confess "Type $old_type isn't mapped to an new class!" unless exists $types{$old_type};
        my $new_type = $types{$old_type};

        for my $type ($new_type, $old_type) {
            confess "Could not get meta object for $type!" unless $type->__meta__;
        }

        $self->status_message("\nSyncing $new_type and $old_type");
        $self->status_message("Creating iterators...");
        my $new_iterator = $new_type->create_iterator;
        my $old_iterator = $old_type->create_iterator;

        my $created_objects = 0;
        my $seen_objects = 0;

        # The rows in the old/new tables have the same IDs. UR sorts these objects by their
        # IDs internally, so simply iterating over old/new objects and checking the IDs is
        # enough to determine if an object is missing.
        # TODO I believe Tony is playing around with order by, which would be preferable to relying
        # on the assumption that UR sorts things by IDs.
        $self->status_message("Iterating over all objects and copying as needed");
        my $new_object = $new_iterator->next;
        my $old_object = $old_iterator->next;

        while ($new_object or $old_object) {
            $seen_objects++;
            my $object_created = 0;
            my $new_id = $new_object->id if $new_object;
            my $old_id = $old_object->id if $old_object;

            # Old iterator exhausted, record IDs of objects in new table but not in the old. In the case of
            # instrument data, this means the data may have been expunged. In other cases, apipe may need to know.
            if ($new_object and not $old_object) {
                push @{$report{$new_type}{'missing'}}, $new_id;
                $new_object = $new_iterator->next;
            }
            # New iterator exhausted, so copy any old objects still remaining.
            elsif ($old_object and not $new_object) {
                if ($self->copy_object($old_object, $new_type)) {
                    $created_objects++;
                    $object_created = 1;
                    push @{$report{$new_type}{'copied'}}, $old_id;
                }
                $old_object = $old_iterator->next;
            }
            else {
                # If IDs are equal, iterate both old and new and continue
                if ($new_id eq $old_id) {
                    $new_object = $new_iterator->next;
                    $old_object = $old_iterator->next;
                }
                # If new ID is less than old ID, then we are missing an old object (since the iterator skipped over several)
                elsif ($new_id lt $old_id) {
                    push @{$report{$new_type}{'missing'}}, $new_id;
                    $new_object = $new_iterator->next;
                }
                # Old ID is less than new ID, so a new object needs to be created
                else {
                    if ($self->copy_object($old_object, $new_type)) {
                        $created_objects++;
                        $object_created = 1;
                        push @{$report{$new_type}{'copied'}}, $old_id;
                    }
                    $old_object = $old_iterator->next;
                }
            }

            print STDERR "\n" and $self->print_object_cache_summary if $self->show_object_cache_summary and $seen_objects % 1000 == 0;

            # Periodic commits to prevent lost progress in case of failure
            if ($created_objects != 0 and $created_objects % 1000 == 0 and $object_created) {
                confess 'Could not commit!' unless UR::Context->commit;
            }

            print STDERR "Looked at $seen_objects objects, created $created_objects\r";
        }
        print STDERR "\n";
        
        confess 'Could not commit!' unless UR::Context->commit;
        $self->print_object_cache_summary if $self->show_object_cache_summary;
        $self->status_message("Done syncning $new_type and $old_type");
    }
    print STDERR "\n";

    $self->_report(\%report);
    my $report_string = $self->generate_report;
    print $report_string;
    $self->write_report_file($report_string) if defined $self->report_file;
    return 1;
}

# Looks at the UR object cache and prints out how many objects of each type are loaded
sub print_object_cache_summary {
    my $self = shift;
    for my $type (sort keys %$UR::Context::all_objects_loaded) {
        my $count = scalar keys %{$UR::Context::all_objects_loaded->{$type}};
        next unless $count > 0;
        $self->status_message("$type : $count");
    }
    return 1;
}

# Generates a summary report with number of objects missing/copied per type
sub generate_report {
    my $self = shift;
    return $self->generate_detailed_report if $self->detailed_report;

    my %report = %{$self->_report};
    my $string;
    for my $type (sort keys %report) {
        $string .= "Type $type";
        for my $operation (qw/ copied missing /) {
            my $num = 0;
            if (exists $report{$type}{$operation}) {
                $num = scalar @{$report{$type}{$operation}};
            }
            $string .= (', ' . (ucfirst $operation) . " $num");
        }
        $string .= "\n";
    }
    return $string;
}

# Generates a string representation of the report hash, which details the objects that were copied from the
# old tables to the new and also lists those IDs that exist in the new tables but not the old.
sub generate_detailed_report {
    my $self = shift;
    my %report = %{$self->_report};

    my $string;
    for my $type (sort keys %report) {
        $string .= "*** Type $type ***\n";
        for my $operation (qw/ copied missing /) {
            next unless exists $report{$type}{$operation};
            $string .= ucfirst $operation . "\n";
            $string .= join("\n", @{$report{$type}{$operation}}) . "\n";
        }
    }
    
    return $string;
}

# Writes report string to a file
sub write_report_file {
    my ($self, $report_string) = @_;
    my $fh = IO::File->new($self->report_file, 'w');
    if ($fh) {
        $fh->print($report_string);
    }
    else {
        $self->warning_message("Could not get file handle for " . $self->report_file . ", not writing report");
    }
    return 1;
}

# Create a new object of the given class based on the given object
sub copy_object {
    my ($self, $original_object, $new_object_class) = @_;
    my $method_base = lc $original_object->class;
    $method_base =~ s/Genome::Site::WUGC:://i;
    $method_base =~ s/::/_/g;
    my $create_method = '_create_' . $method_base;
    if ($self->can($create_method)) {
        return $self->$create_method($original_object, $new_object_class);
    }
    else {
        confess "Did not find method $create_method, cannot create object of type $new_object_class!";
    }
}

# Returns indirect and direct properties for an object and the values those properties hold
sub _get_direct_and_indirect_properties_for_object {
    my ($self, $original_object, $class, @ignore) = @_;
    my %direct_properties;
    my %indirect_properties;

    my @properties = $class->__meta__->properties;
    for my $property (@properties) {
        next if $property->is_calculated;
        next if $property->is_constant;
        next if $property->is_many;
        next if $property->via and $property->via ne 'attributes';
    
        my $property_name = $property->property_name;
        next unless $original_object->can($property_name);
        next if @ignore and grep { $property_name eq $_ } @ignore;

        my $value = $original_object->$property_name;
        next unless defined $value;

        if ($property->via) {
            $indirect_properties{$property_name} = $value;
        }
        else {
            $direct_properties{$property_name} = $value;
        }
    }

    return (\%direct_properties, \%indirect_properties);
}

sub _create_instrumentdata_imported {
    my ($self, $original_object, $new_object_class) = @_;

    # Instrument data is first made with just direct properties. Excluding indirect properties saves UR the 
    # work of determining if the property is indirect and figuring out if the property needs to be updated or
    # created.
    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
        qw/ sample_name sample_id _old_sample_name _old_sample_id /
    );
    
    my $object = eval {
        $new_object_class->create(
            %{$direct_properties},
            id => $original_object->id,
            subclass_name => $new_object_class,
        );
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    # Manually create indirect attributes
    for my $name (sort keys %{$indirect_properties}) {
        Genome::InstrumentDataAttribute->create(
            instrument_data_id => $object->id,
            attribute_label => $name,
            attribute_value => $indirect_properties->{$name}, 
        )
    }

    return 1;
}

sub _create_instrumentdata_solexa {
    my ($self, $original_object, $new_object_class) = @_;

    my $ii = $original_object->index_illumina;
    return 0 unless $ii->copy_sequence_files_confirmed_successfully; #wait for the bam_path to be available
    
    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
        qw/ sample_name sample_id /
    );
    
    my $object = eval {
        $new_object_class->create(
            %{$direct_properties},
            id => $original_object->id,
            subclass_name => $new_object_class,
        );
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    for my $name (sort keys %{$indirect_properties}) {
        Genome::InstrumentDataAttribute->create(
            instrument_data_id => $object->id,
            attribute_label => $name,
            attribute_value => $indirect_properties->{$name}, 
        )
    }

    return 1;
}

sub _create_instrumentdata_sanger {
    my ($self, $original_object, $new_object_class) = @_;

    # Some sanger instrument don't have a library. If that's the case here, just don't create the object
    return 0 unless defined $original_object->library_id or defined $original_object->library_name or defined $original_object->library_summary_id;
    my %library_params;
    if (defined $original_object->library_id) {
        $library_params{id} = $original_object->library_id;
    }
    elsif (defined $original_object->library_name) {
        $library_params{name} = $original_object->library_name;
    }
    else {
        $library_params{id} = $original_object->library_summary_id;
    }
    my $library = Genome::Library->get(%library_params);
    return 0 unless $library;

    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
        qw/ sample_name sample_id /
    );

    my $object = eval {
        $new_object_class->create(
            %{$direct_properties},
            library_id => $library->id,
            id => $original_object->id,
            subclass_name => $new_object_class,
        )
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    for my $name (sort keys %{$indirect_properties}) {
        Genome::InstrumentDataAttribute->create(
            instrument_data_id => $object->id,
            attribute_label => $name,
            attribute_value => $indirect_properties->{$name}, 
        );
    }

    return 1;
}

sub _create_instrumentdata_454 {
    my ($self, $original_object, $new_object_class) = @_;

    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
        qw/ sample_name sample_id full_path/
    );

    my $object = eval {
        $new_object_class->create(
            %{$direct_properties},
            id => $original_object->id,
            subclass_name => $new_object_class,
        )
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$!" unless $object;

    for my $name (sort keys %{$indirect_properties}) {
        Genome::InstrumentDataAttribute->create(
            instrument_data_id => $object->id,
            attribute_label => $name,
            attribute_value => $indirect_properties->{$name}, 
        );
    }
    
    # TODO Need to talk to Scott about how to go about dumping SFF files. Currently, this info is stored in a
    # LIMS table and dumped to the filesystem as an SFF file on demand, see Genome::InstrumentData::454->sff_file.
    # The sff_file method uses GSC::* objects and will need to be moved to Genome/Site/WUGC. To accomplish this, 
    # we can either dump all SFF files from the db and add the dumping logic here in the sync tool, or we can forego
    # the mass dumping and do it manually as needed (it would still be done here as the data is synced).

    return 1;
}

sub _create_sample {
    my ($self, $original_object, $new_object_class) = @_;

    my ($direct_properties, $indirect_properties) = $self->_get_direct_and_indirect_properties_for_object(
        $original_object,
        $new_object_class, 
    );

    # Capture attributes that are attached to the object but aren't spelled out in class definition
    for my $attribute ($original_object->attributes) {
        $indirect_properties->{$attribute->name} = $attribute->value;
    }

    my $object = eval { 
        $new_object_class->create(
            %{$direct_properties},
            id => $original_object->id, 
            subclass_name => $new_object_class
        ) 
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    # The genotype data link doesn't have the same name between LIMS/Apipe and it isn't set as mutable, so it
    # can only be set expclitly as below.
    my $genotype_id = delete $indirect_properties->{default_genotype_seq_id};
    if (defined $genotype_id) {
        # TODO If LIMS ever figures out how to set default genotype data to none, this logic will need to be revised.
        # Currently, the organism_sample table's default_genotype_seq_id column is a foreign key, so it would be 
        # diffiult to elegantly allow none to be set.
        $object->set_default_genotype_data($genotype_id);
    }

    for my $property_name (sort keys %{$indirect_properties}) {
        Genome::SubjectAttribute->create(
            subject_id => $object->id,
            attribute_label => $property_name,
            attribute_value => $indirect_properties->{$property_name},
        );
    }

    return 1;
}

sub _create_populationgroup {
    my ($self, $original_object, $new_object_class) = @_;

    # No attributes/indirect properties, etc to worry about here (except members, below)
    my %params;
    for my $property ($new_object_class->__meta__->_legacy_properties) {
        my $property_name = $property->property_name;
        $params{$property_name} = $original_object->{$property_name} if defined $original_object->{$property_name};
    }
    
    # Grab members from old object and pass to create parameters
    my @member_ids = map { $_->id } $original_object->members;
    $params{member_ids} = \@member_ids;

    my $object = eval { 
        $new_object_class->create(
            %params, 
            id => $original_object->id, 
            subclass_name => $new_object_class
        ) 
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    return 1;
}

sub _create_library {
    my ($self, $original_object, $new_object_class) = @_;

    my %params;
    for my $property ($new_object_class->__meta__->_legacy_properties) {
        my $property_name = $property->property_name;
        $params{$property_name} = $original_object->{$property_name} if defined $original_object->{$property_name};
    }

    my $object = eval { 
        $new_object_class->create(
            %params, 
            id => $original_object->id, 
        ) 
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    return 1;
}

sub _create_individual {
    my ($self, $original_object, $new_object_class) = @_;
    return $self->_create_taxon($original_object, $new_object_class);
}

sub _create_taxon {
    my ($self, $original_object, $new_object_class) = @_;

    my %params;
    for my $property ($new_object_class->__meta__->_legacy_properties) {
        my $property_name = $property->property_name;
        $params{$property_name} = $original_object->{$property_name} if defined $original_object->{$property_name};
    }

    my $object = eval { 
        $new_object_class->create(
            %params, 
            id => $original_object->id, 
            subclass_name => $new_object_class
        ) 
    };
    confess "Could not create new object of type $new_object_class based on object of type " .
        $original_object->class . " with id " . $original_object->id . ":\n$@" unless $object;

    return 1;
}

1;

