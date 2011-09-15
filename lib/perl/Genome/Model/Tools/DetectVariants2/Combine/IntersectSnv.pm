package Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'snvs',
            doc => 'variant type that this module operates on',
        },
    ],

};


sub help_brief {
    "Intersect two snv variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 combine intersect-snv --input-a ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

1;
