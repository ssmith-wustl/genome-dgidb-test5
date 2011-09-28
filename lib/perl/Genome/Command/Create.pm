package Genome::Command::Create;

use strict;
use warnings;

use Genome;
      
require Carp;
use Data::Dumper 'Dumper';
require Lingua::EN::Inflect;

class Genome::Command::Create {
    is => 'Command::V2',
    is_abstract => 1,
    doc => 'CRUD create command class.',
};

sub _target_class { Carp::confess('Please use CRUD or implement _target_class in '.$_[0]->class); }
sub _target_name { Carp::confess('Please use CRUD or implement _target_name in '.$_[0]->class); }
sub _target_name_pl { return Lingua::EN::Inflect::PL($_[0]->_target_name); }
sub _target_name_a { return Lingua::EN::Inflect::A($_[0]->_target_name); }

sub sub_command_sort_position { .1 };

sub help_brief {
    return 'create '.$_[0]->_target_name_pl;
}

sub help_detail {
    return "This command creates ".$_[0]->_target_name_a.'.';
}

sub execute {
    my $self = shift;

    $self->status_message('Create '.$self->_target_name);

    my $class = $self->class;
    my @properties = grep { $_->class_name eq $class } $self->__meta__->property_metas;
    my %attrs;
    for my $property ( @properties ) {
        my $property_name = $property->property_name;
        my @values = $self->$property_name;
        next if not defined $values[0];
        if ( $property->is_many ) {
            $attrs{$property_name} = \@values;
        }
        else {
            $attrs{$property_name} = $values[0];
        }
    }
    $self->status_message(Dumper(\%attrs));

    my $target_class = $self->_target_class;
    my $obj = $target_class->create(%attrs);
    if ( not $obj ) {
        $self->error_message('Could not create '.$target_class);
        return;
    }

    $self->status_message('Create: '.$obj->id);

    return 1;
}

1;

