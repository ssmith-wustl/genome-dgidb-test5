package Genome::Model::SangerComposite;

use strict;
use warnings;

use above "Genome";

class Genome::Model::SangerComposite {
    is => 'Genome::Model::Composite',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    my $model_dir = $self->_model_directory();
=cut

    $self->store_model_id("polyscan", $self->__polyscan_model_id);
    $self->store_model_id("polyphred", $self->__polyphred_model_id);

=cut
    unless (-e $model_dir) {
        unless (system("mkdir $model_dir") == 0) {
            $self->error_message("Failed to mkdir model dir: $model_dir");
            die;
        }
    }
    my @children = $self->child_models;
    foreach my $child_model(@children){
        $self->error_message("Child model supplied to constructor is invalid!") and die unless $self->_is_valid_child($child_model);
    }

    return $self;
}

sub _is_valid_child{
    my ($self, $child) = @_;
    return undef unless grep { $_ eq $child->type } $self->_valid_types;
}

sub _valid_types{
    my $eslf= shift;
    return qw( polyscan polyphred snp_detector);
}

# Returns current directory where the microarray data is housed
sub _base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/sanger_composite/';
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

# Returns the model id encoded in a file in the model dir
# expects some model type like 'polyphred' or 'polyscan'
sub get_model_id {
    my $self = shift;
    my $type = shift;

    my $model_directory = $self->_model_directory;

    my @model_files = `ls $model_directory/*.$type`;

    unless (scalar(@model_files) == 1) {
        $self->error_message("Expecting 1 $type id, got " . scalar(@model_files));
        die;
    }

    my $model_id = $model_files[0] =~ m/^(\d+)\.$type/;

    return $model_id;
}

# Accessor and mutator method
sub polyscan_model_id {
    my $self = shift;

    return $self->get_model_id('polyscan');
}

# Accessor and mutator method
sub polyphred_model_id {
    my $self = shift;

    return $self->get_model_id('polyphred');

}

sub store_model_id{
    my ($self, $type, $id) = @_;

    my $model_dir = $self->_model_directory;

    unless (system("touch $model_dir/$id.$type") == 0) {
        $self->error_message("Failed to touch $model_dir/$id.$type");
        die;
    }
}

1;

