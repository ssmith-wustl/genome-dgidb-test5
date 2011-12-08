package Genome::Model::Command::Define::SmallRna;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SmallRna {
    is => 'Genome::Model::Command::Define::HelperDeprecated',
    has => [
        ref_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_input => 1,
            doc => 'Name or id of smallrna ref model being analyzed',
        },
        
    ],

};

sub _resolve_param {
    my ($self, $param) = @_;

    my $param_meta = $self->__meta__->property($param);
    Carp::confess("Request to resolve unknown property '$param'.") if (!$param_meta);
    my $param_class = $param_meta->data_type;

    my $value = $self->$param;
    return unless $value; # not specified
    return $value if ref($value); # already an object

    my @objs = $self->resolve_param_value_from_text($value, $param_class);
    if (@objs != 1) {
        Carp::confess("Unable to find unique $param_class identified by '$value'. Results were:\n" .
            join('\n', map { $_->__display_name__ . '"' } @objs ));
    }
    $self->$param($objs[0]);
    return $self->$param;
}

sub type_specific_parameters_for_create {
    my $self   = shift;
    my @params = ();

    my %param = (
        ref_model      => $self->ref_model,
    );

    push @params, %param;
    return @params;
}

sub execute {
    my $self = shift;
  
    $self->ref_model($self->_resolve_param('ref_model'));
    unless(defined $self->ref_model) {
        $self->error_message("Could not get a model for smallrna ref model id: " . $self->ref_model_id);
        return;
    }
    
    my $subject  = $self->ref_model->subject;
    $self->subject($subject);

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    return $super->($self,@_);
}

1;

