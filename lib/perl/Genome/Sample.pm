package Genome::Sample; 

use strict;
use warnings;

use Genome;

class Genome::Sample {
    is => 'Genome::Subject',
    has => [
        sample_id => {
            is => 'Text',
            calculate_from => 'subject_id',
            calculate => q{ return $subject_id },
        },
        subject_type => { 
            is => 'Text', 
            is_constant => 1, 
            value => 'organism sample'
        },
    ],
    has_optional => [	
        common_name => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'common_name' ],
            is_mutable => 1,
            doc => 'a name like "tumor1" for a given sample',                                        
        },
        extraction_label => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'extraction_label' ],
            is_mutable => 1,
            doc => 'identifies the specimen sent from the laboratory which extracted DNA/RNA',
        },
        extraction_type => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'extraction_type' ],
            is_mutable => 1,
            doc => 'either "genomic dna" or "rna" in most cases',
        },
        extraction_desc => { 
            is => 'Text', 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'extraction_desc' ],
            is_mutable => 1,
            doc => 'notes specified when the specimen entered this site', 
        },
        cell_type => {         
            is => 'Text', 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'cell_type' ],
            is_mutable => 1,
            doc => 'typically "primary"' 
        },
        tissue_label => {
            is => 'Text', 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'tissue_label' ],
            is_mutable => 1,
            doc => 'identifies/labels the original tissue sample from which this extraction was made' 
        },
        tissue_desc => { 
            is => 'Text', 
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'tissue_desc' ],
            is_mutable => 1,
            doc => 'describes the original tissue sample',
        },
        organ_name => { 
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'organ_name' ],
            is_mutable => 1,
            doc => 'the name of the organ from which the sample was taken' 
        }, 
        # Info about sample source (population group and individual)
        # these are optional only b/c our data is not fully back-filled
        source_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'source_id' ],
            is_mutable => 1,
        },
        source => { 
            is => 'Genome::Subject',
            id_by => 'source_id',
            doc => 'The patient/individual organism from which the sample was taken, or the population for pooled samples.',
        },
        source_type => { 
            is => 'Text',
            calculate_from => 'source',
            calculate => q{ 
                return unless $source;
                return $source->subject_type; 
            },
        },
        source_name => { 
            via => 'source', 
            to => 'name' 
        },
        source_common_name => { 
            via => 'source', 
            to => 'common_name' 
        },
        # the above are overly generic, since all of our sources are Genome::Individuals, and slow, so...
        patient => { 
            is => 'Genome::Individual', 
            id_by => 'source_id',
            doc => 'The patient/individual organism from which the sample was taken.' 
        },
        patient_name => { 
            via => 'patient', 
            to => 'name', 
            doc => 'the system name for a patient (subset of the sample name)' 
        },
        patient_common_name => { 
            via => 'patient', 
            to => 'common_name', 
            doc => 'names like AML1, BRC50, etc' 
        },
        age => { 
            is => 'Number',
            via => 'attributes', 
            to => 'attribute_value',
            where => [ attribute_label => 'age' ], 
            is_mutable => 1,
            doc => 'Age of the patient at the time of sample taking.',
        },
        body_mass_index => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'body_mass_index' ],
            is_mutable => 1,
            doc => 'BMI of the patient at the time of sample taking.',
        },
        tcga_name => { 
            via => 'attributes', 
            to => 'attribute_value',
            where => [ 'nomenclature like' => 'TCGA%', attribute_label => 'biospecimen_barcode_side'], 
            is_mutable => 1,
        },
        # Taxon properties
        taxon_id => {
            is => 'Number',
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'taxon_id' ],
            is_mutable => 1,
        },
        taxon => {
            is => 'Genome::Taxon',
            id_by => 'taxon_id',
        },
        species_name => { 
            calculate_from => 'taxon',
            calculate => q{ 
                return unless $taxon;
                return $taxon->name; 
            },
            doc => 'the name of the species of the sample source\'s taxonomic category' 
        },
        # TODO What are these for? What do they represent?
        sub_type => { 
            calculate_from => ['_sub_type1','_sub_type2'], 
            calculate => q|$_sub_type1 or $_sub_type2| 
        }, 
        _sub_type1 => { 
            via => 'attributes', 
            to => 'attribute_value', 
            where => [ attribute_label => 'sub-type' ], 
            is_mutable => 1,
        },
        _sub_type2 => { 
            via => 'attributes', 
            to => 'attribute_value',
            where => [ attribute_label => 'subtype' ], 
            is_mutable => 1,
        },
        models => { 
            is => 'Genome::Model', 
            reverse_as => 'subject', 
            is_many => 1,
        },
        # TODO These can be removed when project is refactored
        project_assignments          => { is => 'Genome::Sample::ProjectAssignment', reverse_as => 'sample', is_many => 1 },
        projects                     => { is => 'Genome::Site::WUGC::Project', via => 'project_assignments', to => 'project', is_many => 1},
    ],
    has_many => [
        libraries => { 
            is => 'Genome::Library', 
            is_optional => 1,
            calculate_from => 'id',
            calculate => q{ return Genome::Library->get(sample_id => $id) },
        },
        library_names => { via => 'libraries', to => 'name', is_optional => 1, },
        solexa_lanes                => { is => 'Genome::InstrumentData::Solexa', reverse_as => 'sample' },
        solexa_lane_names           => { via => 'solexa_lanes', to => 'full_name' },
    ],

    doc         => 'a single specimen of DNA or RNA extracted from some tissue sample',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = $_[0];
    return $self->name . ($self->patient_common_name ? ' (' . $self->patient_common_name . ' ' . $self->common_name . ')' : '');
}

sub sample_type {
    shift->extraction_type(@_);
}

sub models {
    my $self = shift;
    # only returns models who's subject are Genome::Sample
    my @m = Genome::Model->get(subject_id => $self->id, subject_class_name => $self->class);
    return @m;
}

sub canonical_model {

    # TODO: maybe this should use model is_default?

    my ($self) = @_;

    my @models = sort { $a->id <=> $b->id } $self->models();
    return $models[0];
}

sub get_organism_taxon {
    #emulates GSC::Organism::Sample->get_organism_taxon to get the "right" taxon
    my $self = shift;
    my $population = $self->get_population;
    if ($population){
        return $population->taxon; 
    }
    if(!$self->taxon_id){
        return $self->patient->taxon if $self->patient;
    }
    return $self->taxon;
}

sub get_population {
    #emulates GSC::Organism::Sample->get_population
    my $self = shift;
    my $source_type = $self->source_type;
    if($source_type && 
            ($source_type eq 'organism individual' || 
             $source_type eq 'population group')){
        return $self->source;
    }
    return;
}   

sub default_genotype_data {
    my $self = shift;
    my $sample_attribute = $self->attributes('default_genotype_data');
    my $genotype_data = Genome::InstrumentData->get($sample_attribute->attribute_value);
    return $genotype_data;
}

sub set_default_genotype_data {
    my $self = shift;
    my $genotype_instrument_data = shift;

    die $self->error_message("No genotype instrument data provided.")
        unless ($genotype_instrument_data);

    die $self->error_message("Genotype instrument data is not a Genome::InstrumentData::Imported object.")
        unless ($genotype_instrument_data->isa('Genome::InstrumentData::Imported'));

    die $self->error_message("Instrument data is not a 'genotype file' format.")
        unless ($genotype_instrument_data->import_format && $genotype_instrument_data->import_format eq 'genotype file');

    $self->add_attribute(
        attribute_label => 'default_genotype_data',
        attribute_value => $genotype_instrument_data->id,
    );
}

sub default_genotype_builds {
    my $self = shift;

    my $genotype_data = $self->default_genotype_data;
    return unless ($genotype_data);

    my @inputs = Genome::Model::Build::Input->get(
        value_class_name => $genotype_data->class,
        value_id => $genotype_data->id,
    );
    my @builds = map { $_->build } @inputs;
    @builds = grep { $_->status eq 'Succeeded' } @builds;
    @builds = grep { $_->model->last_succeeded_build->id eq $_->id } @builds;
    @builds = grep { $_->isa('Genome::Model::Build::GenotypeMicroarray') } @builds;

    $self->warning_message("No default genotype builds found.")
        unless (@builds);

    return @builds;
}

1;
