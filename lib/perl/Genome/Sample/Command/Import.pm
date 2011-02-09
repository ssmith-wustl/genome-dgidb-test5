package Genome::Sample::Command::Import;

use strict;
use warnings;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Sample::Command::Import {
    is => 'Command',
    is_abstract => 1,
    doc => 'Import samples from known sources',
    has => [
        _taxon => { is => 'Genome::Taxon', is_optional => 1, },
        _individual => { is => 'Genome::Individual', is_optional => 1, },
        _sample => { is => 'Genome::Sample', is_optional => 1, },
        _library => { is => 'Genome::Library', is_optional => 1, },
        _created_objects => { is => 'ARRAY', is_optional => 1, },
    ],
};

sub help_brief {
    my $class = shift;
    my $name = $class->command_name_brief;
    if ( $name  eq 'import' ) { # base
        return 'import samples from known sources';
    }
    else {
        return "import $name samples";
    }
}

sub help_detail {
    return help_brief();
}

sub _update_object {
    my ($self, $obj, %params) = @_;

    $self->status_message('Update '.$obj->name.' ('.$obj->id.')');
    $self->status_message( Dumper(\%params) );

    for my $attr ( keys %params ) {
        $obj->$attr( $params{$attr} );
    }

    if ( not UR::Context->commit ) {
        $self->_bail('Cannot commit updates');
        return;
    }

    $self->status_message('Update...OK');

    return 1;
}

sub _get_taxon {
    my ($self, $name) = @_;

    Carp::confess('No name given to get taxon') if not $name;

    my $taxon = Genome::Taxon->get(name => $name);
    return if not $taxon;

    $self->status_message('Taxon: '.join(' ', map{ $taxon->$_ } (qw/ id name/)));

    return $self->_taxon($taxon);
}

sub _get_and_update_or_create_individual {
    my ($self, %params) = @_;

    my $individual = $self->_get_individual($params{name});
    if ( $individual ) {
        my $update = $self->_update_object($individual, %params);
        return if not $update;
    }
    else {
        $individual = $self->_create_individual(%params);
        return if not $individual;
    }
   
    return $individual;
}

sub _get_individual {
    my ($self, $name) = @_;

    Carp::confess('No name given to get individual') if not $name;

    my $individual = Genome::Individual->get(name => $name);
    return if not defined $individual;

    $self->status_message('Individual: '.join(' ', map{ $individual->$_ } (qw/ id name/)));

    return $self->_individual($individual);
}

sub _create_individual {
    my ($self, %params) = @_;

    Carp::confess('No individual name given to create individual') if not $params{name};
    Carp::confess('No taxon set to create individual') if not $self->_taxon;

    $params{upn} = $params{name} if not $params{upn};
    $params{taxon_id} = $self->_taxon->id;
    $params{gender} = 'unspecified' if not $params{gender};
    $params{nomenclature} = 'WUGC' if not $params{nomenclature};

    $self->status_message('Create individual: '.Dumper(\%params));
    my $individual = Genome::Individual->create(%params);
    if ( not defined $individual ) {
        $self->_bail('Could not create individual');
        return;
    }

    if ( not UR::Context->commit ) {
        $self->_bail('Cannot commit new individual to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $individual;
    $self->_created_objects($created_objects);
    $self->status_message('Individual: '.join(' ', map{ $individual->$_ } (qw/ id name/)));

    return $self->_individual($individual);
}

sub _get_and_update_or_create_sample {
    my ($self, %params) = @_;

    if ( $self->_individual ) {
        $params{source_id} = $self->_individual->id;
        $params{source_type} = $self->_individual->subject_type;
    }

    my $sample = $self->_get_sample($params{name});
    if ( $sample ) {
        my $update = $self->_update_object($sample, %params);
        return if not $update;
    }
    else {
        $sample = $self->_create_sample(%params);
        return if not $sample;
    }
   
    return $sample;
}

sub _validate_or_set_sample_params {
    my ($self, $params) = @_;

    Carp::confess('No sample params given to validate or set') if not $params;
    Carp::confess('Need sample params as hash ref to validate or set') if ref $params ne 'HASH';

    if ( $self->_individual ) {
        $params->{source_id} = $self->_individual->id;
        $params->{source_type} = $self->_individual->subject_type;
    }

    if ( $params->{nomenclature} ) {
        my $nomenclature = GSC::Nomenclature->get($params->{nomenclature});
        return if not $nomenclature;
        $params->{_nomenclature} = delete $params->{nomenclature};
    }
    elsif ( not defined $params->{_nomenclature} ) {
        $params->{_nomenclature} = 'WUGC';
    }

    if ( defined $params->{organ_name} ) {
        my $organ = GSC::Organ->get($params->{organ_name});
        return if not $organ;
    }

    if ( defined $params->{tissue_desc} ) {
        my $tissue = $self->_get_or_create_tissue($params->{tissue_desc});
        return if not $tissue;
    }

    return 1;
}

sub _get_sample {
    my ($self, $name) = @_;

    Carp::confess('No name given to get sample') if not $name;

    my $sample = Genome::Sample->get(name => $name);
    return if not defined $sample;

    $self->status_message('Sample: '.join(' ', map{ $sample->$_ } (qw/ id name/)));

    return $self->_sample($sample);
}

sub _create_sample {
    my ($self, %params) = @_;

    Carp::confess('No name given to create sample') if not $params{name};

    my $validate_or_set = $self->_validate_or_set_sample_params(\%params);
    return if not $validate_or_set;

    $self->status_message('Create sample: '.Dumper(\%params));
    my $sample = Genome::Sample->create(%params);
    if ( not defined $sample ) {
        $self->_bail('Cannot create sample');
        return;
    }

    if ( not UR::Context->commit ) {
        $self->_bail('Cannot commit new sample to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $sample;
    $self->_created_objects($created_objects);

    $self->status_message('Sample: '.join(' ', map { $sample->$_ } (qw/ id name /)));

    return $self->_sample($sample);
}

sub _get_or_create_tissue {
    my ($self, $tissue_name) = @_;

    my $tissue = GSC::Tissue->get($tissue_name);

    if ( defined $tissue ) {
        $self->status_message('Tissue: '.$tissue->tissue_name);
        return 1;
    }

    $self->status_message('Creating tissue: '.Dumper({ tissue_name => $tissue_name }));
    $tissue = GSC::Tissue->create(tissue_name => $tissue_name);
    if ( not defined $tissue ) {
        $self->_bail('Cannot create tissue: '.$tissue_name);
        return;
    }

    unless ( UR::Context->commit ) {
        $self->_bail('Cannot commit tissue to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $tissue;
    $self->_created_objects($created_objects);

    $self->status_message('Tissue: '.$tissue->tissue_name);

    return $tissue;
}

sub _get_or_create_library_for_extension {
    my ($self, $ext) = @_;

    my $library = $self->_get_library_for_extension($ext);
    return $library if $library;

    return $self->_create_library_for_extension($ext);
}

sub _get_library_name_for_extension {
    my ($self, $ext) = @_;

    Carp::confess('No sample set to get or create library') if not $self->_sample;
    Carp::confess('No library extension') if not defined $ext;
    my @valid_exts = (qw/ extlibs microarraylib /);
    Carp::confess("Invalid library extension ($ext). Valid extentions: ".join(' ', @valid_exts)) if not grep { $ext eq $_ } @valid_exts;

    return $self->_sample->name.'-'.$ext;
}

sub _get_library_for_extension {
    my ($self, $ext) = @_;

    my $name = $self->_get_library_name_for_extension($ext); # confess on error
    my $library = Genome::Library->get(name => $name);
    return if not $library;

    $self->status_message('Library: '.join(' ', map{ $library->$_ } (qw/ id name/)));

    return $self->_library($library);

}

sub _create_library_for_extension {
    my ($self, $ext) = @_;

    my %params = (
        name => $self->_get_library_name_for_extension($ext), # confess on error
        sample_id => $self->_sample->id,
    );

    $self->status_message('Creating library: '.Dumper(\%params));
    my $library = Genome::Library->create(%params);
    if ( not $library ) {
        $self->_bail('Cannot not create library to import sample');
        return;
    }

    unless ( UR::Context->commit ) {
        $self->_bail('Cannot commit new library to DB');
        return;
    }

    my $created_objects = $self->_created_objects;
    push @$created_objects, $library;
    $self->_created_objects($created_objects);

    $self->status_message('Library: '.join(' ', map{ $library->$_ } (qw/ id name/)));
    
    return $self->_library($library);
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

