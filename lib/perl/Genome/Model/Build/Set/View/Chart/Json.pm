package Genome::Model::Build::Set::View::Chart::Json;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Set::View::Chart::Json {
    is => 'UR::Object::Set::View::Default::Json',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'rule_display',
                {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'json',
                    aspects => [
                        'metrics',
                    ],
                    subject_class_name => 'Genome::Model::Metric',
                },
            ]
        }
    ]
};
                    #name => 'members',
                    #aspects => [
                    #    'build_id',
                    #    'metrics'
                    #],

1;
