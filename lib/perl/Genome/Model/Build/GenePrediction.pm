package Genome::Model::Build::GenePrediction;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Model::Build::GenePrediction {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => {
            calculate_from => 'model_id',
            calculate => sub {
                my $model_id = shift;
                my $model = Genome::Model->get($model_id);
                confess "Could not get model $model_id!" unless $model;
                my $pp = $model->processing_profile;
                my $domain = $pp->domain;
                my $camel_case = Genome::Utility::Text::string_to_camel_case($domain);
                return 'Genome::Model::Build::GenePrediction::' . $camel_case;
            },
        },
    ],
};

1;

