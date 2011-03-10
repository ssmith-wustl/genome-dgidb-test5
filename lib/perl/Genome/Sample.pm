
package Genome::Sample; 

# Adaptor for GSC::Organism::Sample

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require File::Basename;
require File::Copy;

=pod

    table_name => q|
        (
            select
                --fully precise and connected to LIMS
                s.organism_sample_id    id,
                s.full_name             name,
                s.common_name           common_name,

                -- collaborator's output
                s.sample_name           extraction_label,
                s.sample_type           extraction_type,
                s.description           extraction_desc,

                -- collaborator's source
                s.cell_type,
                s.tissue_label,
                s.tissue_name           tissue_desc,
                s.organ_name,

                -- patient, environment, or group for pools
                s.source_id,
                s.source_type,

                -- species/strain
                s.taxon_id              taxon_id
            from GSC.organism_sample s
        ) sample
    |,

=cut

class Genome::Sample {
    is => 'Genome::Measurable',
    table_name => 'GSC.ORGANISM_SAMPLE',
    id_by => [
        id                          => { is => 'Number',
                                        doc => 'the numeric ID for the specimen in both the LIMS and the analysis system', 
                                        column_name => 'ORGANISM_SAMPLE_ID',
                                    },
    ],
    has => [
        name                        => { is => 'Text',     len => 64, 
                                        doc => 'the fully qualified name for the sample (the "DNA NAME" in LIMS for both DNA and RNA)', 
                                        column_name => 'FULL_NAME',
                                    },
        subject_type => { is => 'Text', is_constant => 1, value => 'organism sample', column_name => '', },
        nomenclature                => { column_name => 'NOMENCLATURE', default_value => "WUGC" }, 

    ],
    has_optional => [	
        common_name                 => { is => 'Text', 
                                        doc => 'a name like "tumor1" for a given sample',                                        
                                    },

        extraction_label            => { is => 'Text', 
                                        doc => 'identifies the specimen sent from the laboratory which extracted DNA/RNA',
                                        column_name => 'SAMPLE_NAME',
                                    },
                
        extraction_type             => { is => 'Text', 
                                        doc => 'either "genomic dna" or "rna" in most cases', column_name => 'SAMPLE_TYPE' },
                
        extraction_desc             => { is => 'Text', 
                                        doc => 'notes specified when the specimen entered this site', 
                                        column_name => 'DESCRIPTION'
                                    },
                
        cell_type                   => { is => 'Text', len => 100,
                                        doc => 'typically "primary"' },

        tissue_label	            => { is => 'Text', 
                                        doc => 'identifies/labels the original tissue sample from which this extraction was made' },
        								
        tissue_desc                 => { is => 'Text', len => 64, 
                                        doc => 'describes the original tissue sample', column_name => 'TISSUE_NAME' },
        
        organ_name                  => { is => 'Text', len => 64, 
                                        doc => 'the name of the organ from which the sample was taken' }, 
        
        # these are optional only b/c our data is not fully back-filled
        source => { 
            is => 'Genome::Measurable',
            id_by => 'source_id',
            where => [ 'subject_type in' => [qw/ organism_individual population_group /, 'organism individual', 'population group', ]],
            doc => 'The patient/individual organism from which the sample was taken, or the population for pooled samples.',
        },
        source_type                 => { is => 'Text',
                                        doc => 'either "organism individual" for individual patients, or "population group" for cross-individual samples' },
        
        source_name                 => { via => 'source', to => 'name' },
        
        source_common_name          => { via => 'source', to => 'common_name' },


        # the above are overly generic, since all of our sources are Genome::Individuals, and slow, so...
        patient                      => { is => 'Genome::Individual', id_by => 'source_id',
                                           doc => 'The patient/individual organism from which the sample was taken.' },
        
        patient_name                 => { via => 'patient', to => 'name', doc => 'the system name for a patient (subset of the sample name)' },
        
        patient_common_name          => { via => 'patient', to => 'common_name', doc => 'names like AML1, BRC50, etc' },
        age => { 
            is => 'Number',
            via => 'attributes', 
            where => [ name => 'age', nomenclature => 'WUGC', ], 
            to => 'value',
            is_optional => 1,
            is_many => 0,
            is_mutable => 1,
            doc => 'Age of the patient at the time of sample taking.',
        },
        body_mass_index => {
            via => 'attributes',
            where => [ name => 'body_mass_index', nomenclature => 'WUGC', ] ,
            to => 'value',
            is_optional => 1,
            is_many => 0,
            is_mutable => 1,
            doc => 'BMI of the patient at the time of sample taking.',
        },
        tcga_name                   => { via => 'attributes', where => [ 'nomenclature like' => 'TCGA%', name => 'biospecimen_barcode_side'], to => 'value' },

        taxon                       => { is => 'Genome::Taxon', id_by => 'taxon_id', 
                                        doc => 'the taxon of the sample\'s source' },
        
        species_name                => { via => 'taxon', to => 'species_name', 
                                        doc => 'the name of the species of the sample source\'s taxonomic category' },

        sub_type                    => { calculate_from => ['_sub_type1','_sub_type2'], calculate => q|$_sub_type1 or $_sub_type2| }, 
        _sub_type1                  => { via => 'attributes', where => [ name => 'sub-type' ], to => 'value' },
        _sub_type2                  => { via => 'attributes', where => [ name => 'subtype' ], to => 'value' },
        
        models                      => { is => 'Genome::Model', reverse_as => 'subject', is_many => 1 },

        project_assignments          => { is => 'Genome::Sample::ProjectAssignment', reverse_id_by => 'sample', is_many => 1 },
        projects                     => { is => 'Genome::Site::WUGC::Project', via => 'project_assignments', to => 'project', is_many => 1},
        disk_allocation => {
            is => 'Genome::Disk::Allocation', 
            is_many => 1,
            reverse_as => 'owner',
            is_optional => 1,
        },
        data_directory => { is => 'Text', via => 'disk_allocation', to => 'absolute_path', },
        ],
        has_many => [
        attributes                  => { is => 'Genome::Sample::Attribute', reverse_as => 'sample', specify_by => 'name', is_optional => 1, is_many => 1, },
        libraries                   => { is => 'Genome::Library', reverse_id_by => 'sample' },
        solexa_lanes                => { is => 'Genome::InstrumentData::Solexa', reverse_id_by => 'sample' },
        solexa_lane_names           => { via => 'solexa_lanes', to => 'full_name' },
    ],
    doc         => 'a single specimen of DNA or RNA extracted from some tissue sample',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = $_[0];
    return $self->name . ($self->patient_common_name ? ' (' . $self->patient_common_name . ' ' . $self->common_name . ')' : '');
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
            allocation_path => '/sample/'.$self->id,
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

sub sample_type {
    shift->extraction_type(@_);
}

sub models {
    my $self = shift;
    my @m = Genome::Model->get(subject_id => $self->id, subject_class_name => $self->class);
    return @m;
}

sub canonical_model {

    # TODO: maybe this should use model is_default?

    my ($self) = @_;

    my @models = sort { $a->id <=> $b->id } $self->models();
    return $models[0];
}

1;

