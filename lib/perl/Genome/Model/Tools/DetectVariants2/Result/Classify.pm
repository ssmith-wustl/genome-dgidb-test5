package Genome::Model::Tools::DetectVariants2::Result::Classify;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Result::Classify {
    is => ['Genome::Model::Tools::DetectVariants2::Result::Base'],
    is_abstract => 1,
    has_input =>[
        prior_result_id => {
            is => 'Text',
            doc => 'ID of the results to be classified',
        },
    ],
    has_param => [
        classifier_version => {
            is => 'Text',
            doc => 'Version of the classifier to use',
        },
    ],
    has => [
        prior_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'prior_result_id',
        },
    ],
    doc => '',
};

sub _gather_params_for_get_or_create {
    my $class = shift;

    my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, @_);

    my %params = $bx->params_list;
    my %is_input;
    my %is_param;
    my $class_object = $class->__meta__;
    for my $key ($class->property_names) {
        my $meta = $class_object->property_meta_for_name($key);
        if ($meta->{is_input} && exists $params{$key}) {
            $is_input{$key} = $params{$key};
        } elsif ($meta->{is_param} && exists $params{$key}) {
            $is_param{$key} = $params{$key};
        }
    }

    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_input);
    my $params_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_param);

    my %software_result_params = (
        params_id=>$params_bx->id,
        inputs_id=>$inputs_bx->id,
        subclass_name=>$class,
    );

    return {
        software_result_params => \%software_result_params,
        subclass => $class,
        inputs=>\%is_input,
        params=>\%is_param,
    };
}

1;
