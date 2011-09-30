package Genome::Model::Tools::DetectVariants2::Combine::UnionSv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSv{
    is  => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union svs into one file',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'svs',
            doc => 'variant type that this module operates on',
        },
    ],
};

sub help_brief {
    "union svs into one file",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 combine union-sv --input-a ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;
