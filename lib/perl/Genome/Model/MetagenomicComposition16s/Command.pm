package Genome::Model::MetagenomicComposition16s::Command; 

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::MetagenomicComposition16s::Command {
    is => 'Command',
    is_abstract => 1,
    has => [
        build_identifiers => {
            is => 'Text',
            doc => 'Any combination of build IDs, model IDs and/or model names separated by commas. For model IDs and names, the most recent successful build will be used.',
        },
    ],
};

sub sub_command_category { 'type specific' }

sub _command_name_brief {
    return 'metagenomic-composition-16s';
}

sub _builds {
    my $self = shift;

    my $identifiers = $self->build_identifiers;
    unless ( $identifiers ) {
        $self->error_message("No identifiers to get models.");
        return;
    }

    my @identifiers = split(/,\s*/, $self->build_identifiers);
    unless ( @identifiers ) {
        $self->error_message("Could not split out build identifiers from string: $identifiers");
        return;
    }

    my %builds;
    for my $identifier ( @identifiers ) {
        my $build;
        if ( $identifier !~ /^$RE{num}{int}$/ ) {
            # model name
            $build = $self->_get_last_complete_build_for_model_params(name => $identifier)
                or return; # error in sub
        }
        else { 
            # build id first
            $build = Genome::Model::Build->get($identifier);
            unless ( $build ) {
                # model id
                $build = $self->_get_last_complete_build_for_model_params(id => $identifier)
                    or return; # error in sub
            }
        }
        $builds{ $build->id } = $build;
    }

    return values %builds;
}

sub _get_last_complete_build_for_model_params {
    my ($self, %params) = @_;

    my $model = Genome::Model->get(%params);
    unless ( $model ) {
        $self->error_message("Can't get model for ".join(' => ', %params));
        return;
    }

    my $build = $model->last_complete_build;
    unless ( $build ) {
        $self->error_message("Model (".$model->id.' '.$model->name.") does not have a last completed build");
        return;
    }

    return $build;
}

1;

