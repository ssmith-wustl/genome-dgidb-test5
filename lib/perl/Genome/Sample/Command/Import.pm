package Genome::Sample::Command::Import;

use strict;
use warnings;

use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import {
    is => 'Command',
    doc => 'Import a sample',
    has => [
        # taxon
        _taxon => {
            is_optional => 1,
        },
        taxon_name => { 
            is => 'Text',
            doc => 'Taxon name to use or create',
        },
        # sample
        _sample => {
            is_optional => 1,
        },
        sample_name => { 
            is => 'Text',
            doc => 'Sample name to use or create',
        },
        sample_attrs => {
            is => 'Text',
            is_optional => 1,
            doc => 'Attributes (cell_type, nomenclature, tissue_desc, extraction_label, extraction_type, organ_name...) for creating a sample. Syntax: ATTR1=VAL1,ATTR2=VAL2',
        },
        # individual
        _individual => {
            is_optional => 1,
        },
        individual_name => {
            is => 'Text',
            doc => 'Individual name to use or create',
        },
        individual_attrs => {
            is => 'Text',
            is_optional => 1,
            doc => 'Attributes (common_name, gender, race, ethnicity) for creating an individual. Syntax: ATTR1=VAL1,ATTR2=VAL2',
        },
        # misc
        _created_objects => {
            is => 'ARRAY',
            is_optional => 1,
        },
    ],
};

sub help_brief {
    return 'Import a sample into the system';
}

sub help_detail {
    return <<HELP;
HELP
}

sub execute {
    my $self = shift;

    # Taxon
    $self->_get_taxon 
    #or $self->_create_taxon
        or return;

    # Individual
    $self->_get_individual
        or $self->_create_individual
        or return;

    # Sample
    $self->_get_sample
        or $self->_create_sample
        or return;

    # Library
    $self->_create_library
        or return;

    return 1;
}

sub _attrs_for {
    my ($self, $type) = @_;

    my $attrs_method = $type.'_attrs';
    my $attrs_string = $self->$attrs_method;

    return if not defined $attrs_string;

    my @attr_tokens = split(',', $attrs_string);
    if ( not @attr_tokens ) {
        $self->error_message("Could not get $type attributes from '$attrs_string'");
        return;
    }

    my %attrs;
    for my $token ( @attr_tokens ) {
        my ($key, $val) = split('=', $token);
        if ( not defined $val ) {
            $self->error_message("Could not get attribute key/value pair from '$token'");
        }
        $attrs{$key} = $val;
    }

    return %attrs;
}

sub _get_taxon {
    my $self = shift;

    my $taxon = Genome::Taxon->get(name => $self->taxon_name);

    return if not defined $taxon;

    $self->status_message('Got taxon: '.join(' ', map{ $taxon->$_ } (qw/ id name/)));
    #print Dumper($taxon);
    return $self->_taxon($taxon);
}

sub _create_taxon {
    my $self = shift;

    my %taxon_attrs = $self->_attrs_for('taxon');
    $taxon_attrs{name} = $self->taxon_name;
    $taxon_attrs{species_name} = $self->taxon_name;
    #$taxon_attrs{_legacy_org_id} = 43; # unknow in OLTP

    $self->status_message('Creating taxon: '.Dumper(\%taxon_attrs));
    my $taxon = Genome::Taxon->create(%taxon_attrs);
    if ( not defined $taxon ) {
        $self->_bail('Could not create taxon');
        return;
    }

    unless ( UR::Context->commit ) {
        $self->_bail('Cannot commit new taxon to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $taxon;
    $self->_created_objects($created_objects);

    $self->status_message('Created taxon: '.join(' ', map{ $taxon->$_ } (qw/ id name/)));
    #print Dumper($taxon);
    return $self->_taxon($taxon);
}

sub _get_individual {
    my $self = shift;

    my $individual = Genome::Individual->get(name => $self->individual_name);

    return if not defined $individual;

    $self->status_message('Got individual: '.join(' ', map{ $individual->$_ } (qw/ id name/)));
    #print Dumper($individual);
    return $self->_individual($individual);
}

sub _create_individual {
    my $self = shift;

    my %individual_attrs = $self->_attrs_for('individual');
    $individual_attrs{name} = $self->individual_name;
    $individual_attrs{upn} = $self->individual_name if not defined $individual_attrs{upn};
    $individual_attrs{taxon_id} = $self->_taxon->id;

    $self->status_message('Creating individual: '.Dumper(\%individual_attrs));
    my $individual = Genome::Individual->create(%individual_attrs);
    if ( not defined $individual ) {
        $self->_bail('Could not create individual');
        return;
    }

    unless ( UR::Context->commit ) {
        $self->_bail('Cannot commit new individual to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $individual;
    $self->_created_objects($created_objects);

    $self->status_message('Created individual: '.join(' ', map{ $individual->$_ } (qw/ id name/)));
    #print Dumper($individual);
    return $self->_individual($individual);
}


sub _get_sample {
    my $self = shift;

    my $sample = Genome::Sample->get(
       name => $self->sample_name,
    );

    return if not defined $sample;

    $self->status_message('Got sample: '.join(' ', map{ $sample->$_ } (qw/ id name/)));
    #print Dumper($sample);
    return $self->_sample($sample);
}

sub _create_sample {
    my $self  = shift;

    my %sample_attrs = $self->_attrs_for('sample');
    print Dumper(\%sample_attrs);
    $sample_attrs{name} = $self->sample_name;
    $sample_attrs{extraction_label} = $self->sample_name if not defined $sample_attrs{extraction_label};
    $sample_attrs{taxon_id} = $self->_taxon->id;
    $sample_attrs{source_id} = $self->_individual->id;
    $sample_attrs{source_type} = 'organism individual';
    $sample_attrs{cell_type} = 'unknown' if not defined $sample_attrs{cell_type};

    # organ
    if ( defined $sample_attrs{organ_name} ) {
        $self->_get_organ($sample_attrs{organ_name})
            or return;
    }
 
    # tissue
    if ( defined $sample_attrs{tissue_desc} ) {
        $self->_get_or_create_tissue($sample_attrs{tissue_desc})
            or return;
    }
    
    # nomenclature
    if ( defined $sample_attrs{nomenclature} ) {
        $sample_attrs{_nomenclature} = delete $sample_attrs{nomenclature};
        $self->_get_or_create_nomenclature($sample_attrs{_nomenclature})
            or return;
    }
    else {
        $sample_attrs{_nomenclature} = 'unknown';
    }

    # create
    $self->status_message('Creating sample: '.Dumper(\%sample_attrs));
    my $sample = Genome::Sample->create(%sample_attrs);
    if ( not defined $sample ) {
        $self->error_message('Could not create sample');
        return;
    }

    unless ( UR::Context->commit ) {
        $self->error_message('Cannot commit sample to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $sample;
    $self->_created_objects($created_objects);

    $self->status_message('Created sample: '.join(' ', map{ $sample->$_ } (qw/ id name/)));
    #print Dumper($sample);
    return $self->_sample($sample);
}

sub _get_organ {
    my ($self, $organ_name) = @_;

    my $organ = GSC::Organ->get($organ_name);

    if ( not defined $organ ) {
        $self->status_message("Organ ($organ_name) does not exist. Please create it or use an existing one");
        return;
    }

    $self->status_message('Got organ: '.$organ->organ_name);

    return 1;
}

sub _get_or_create_tissue {
    my ($self, $tissue_name) = @_;

    my $tissue = GSC::Tissue->get($tissue_name);

    if ( defined $tissue ) {
        $self->status_message('Got tissue: '.$tissue->tissue_name);
        return 1;
    }

    $self->status_message('Creating tissue: '.Dumper({ tissue_name => $tissue_name }));
    $tissue = GSC::Tissue->create(tissue_name => $tissue_name);
    if ( not defined $tissue ) {
        $self->error_message('Cannot create tissue: '.$tissue_name);
        return;
    }

    unless ( UR::Context->commit ) {
        $self->error_message('Cannot commit tissue to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $tissue;
    $self->_created_objects($created_objects);

    $self->status_message('Created tissue: '.$tissue->tissue_name);
    return 1;
}

sub _get_or_create_nomenclature {
    my ($self, $nom) = @_;

    my $nomenclature = GSC::Nomenclature->get($nom);

    if ( defined $nomenclature ) {
        $self->status_message('Got nomenclature: '.$nomenclature->nomenclature);
        return 1;
    }

    $self->status_message('Creating nomenclature: '.Dumper({ nomenclature => $nom }));
    $nomenclature = GSC::Tissue->create(nomenclature => $nom);
    if ( not defined $nomenclature ) {
        $self->error_message('Cannot create nomenclature: '.$nom);
        return;
    }

    unless ( UR::Context->commit ) {
        $self->error_message('Cannot commit nomenclature to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $nomenclature;
    $self->_created_objects($created_objects);

    $self->status_message('Created nomenclature: '.$nomenclature->nomenclature);
    return 1;
}

sub _create_library {
    my $self = shift;

    $self->status_message('Creating library: '.Dumper({ sample_id => $self->_sample->id }));
    my $library = Genome::Library->create(
        sample_id => $self->_sample->id,
    );
    if ( not defined $library ) {
        $self->_bail('Could not create library to import sample');
        return;
    }

    unless ( UR::Context->commit ) {
        $self->_bail('Cannot commit library to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $library;
    $self->_created_objects($created_objects);

    $self->status_message('Created library: '.join(' ', map{ $library->$_ } (qw/ id name/)));
    #print Dumper($library);
    return 1;
}

sub _bail {
    my ($self, $msg) = @_;

    $self->error_message($msg);

    my $created_objects = $self->_created_objects;
    return if not defined $created_objects;

    $self->status_message('Encountered an error, removing newly created objects.');

    for my $obj ( @$created_objects ) { 
        $obj->delete;
        if ( not UR::Context->commit ) {
            $self->status_message('Cannot commit removal of '.ref($obj).' '.$obj->id);
        }
    }

    return 1;
}

1;

