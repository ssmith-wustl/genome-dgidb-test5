package Genome::Model::SampleGenotype;

use strict;
use warnings;

use IO::File;
use above "Genome";

class Genome::Model::SampleGenotype{
    is => 'Genome::Model::Composite',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    my $model_dir = $self->_model_directory();

    unless (-e $model_dir) {
        unless (system("mkdir $model_dir") == 0) {
            $self->error_message("Failed to mkdir model dir: $model_dir");
            die;
        }
    }

    return $self;
}

# The file containing the genotype for this sample
sub genotype_file {
    my $self = shift;
    return $self->_model_directory . "/genotype.tsv";
}

# Check to make sure all child types are valid types
sub _is_valid_child{
    my ($self, $child) = @_;
    return undef unless grep { $_ eq $child->type } $self->_valid_types;
}

# The valid children types for this composite
sub _valid_types{
    my $self= shift;
    return qw( polyscan polyphred );
}

# Returns current directory where the microarray data is housed
sub _base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/imported_variants_data/sample_genotype/';
}

# Returns the current directory where this model is housed
# Should work for all submodules
sub _model_directory {
    my $self = shift;

    # Replace all spaces with underbars to insure proper directory access
    my $name = $self->name;
    $name =~ s/ /_/g;

    return $self->_base_directory . "/$name/";
}

# Returns the parameterized model associated with this composite
# Right now, bomb out if we get more than 1
sub get_model_of_type {
    my ($self, $type) = @_;

    my @children = $self->child_models;

    my @models = grep { $_->type eq $type } @children;

    unless (scalar(@models) == 1) {
        $self->error_message("Expected 1 $type model, got " . scalar(@models));
        die;
    }

    return $models[0];
}

# Get the polyscan model associated with this model
sub polyscan_model {
    my $self = shift;

    return  $self->get_model_of_type('polyscan');
}

# Get the polyphred model associated with this model
sub polyphred_model {
    my $self = shift;

    return  $self->get_model_of_type('polyphred');
}

sub combine_variants{
    my $self = shift;
    my $processing_profile = $self->processing_profile;
    my $combine_variants_strategy = $processing_profile->strategy; #TODO?
}

sub create_genotype_file{
    #TODO

}

sub update_genotypes{
    my $self=shift;
    #TODO
    #archive
    #recalculate
    $self->create_genotype_file;
}

sub get_genotypes{
    my $self = shift;
    my %args = @_;
    #TODO wut is the interface?
}

1;
