package Genome::ProcessingProfile::GenePrediction;

use strict;
use warnings;
use Genome;
use Carp qw(confess);

class Genome::ProcessingProfile::GenePrediction {
    is => 'Genome::ProcessingProfile',
    subclassify_by => 'subclass_name',
    is_abstract => 1,
    has => [
        subclass_name => {
            is_mutable => 0,
            calculate_from => 'domain',
            calculate => sub {
                my $domain = shift;
                confess "No domain given to gene prediction processing profile!" unless defined $domain;
                my $camel_case = Genome::Utility::Text::string_to_camel_case($domain);
                return 'Genome::ProcessingProfile::GenePrediction::' . $camel_case;
            },
        },
    ],
    has_param => [
        domain => {
            is => 'Text',
            valid_values => ['bacterial', 'archaeal', 'eukaryotic'],
            doc => 'Domain of organism',
        },
    ],
};

sub _resolve_type_name_for_class {
    return 'gene prediction';
}

sub validate_created_object {
    my $self = shift;
    my $domain = $self->domain;
    my $calculated_subclass = 'Genome::ProcessingProfile::GenePrediction::' . ucfirst $domain;
    my $subclass = $self->subclass_name;

    if ($subclass ne $calculated_subclass) {
        $self->error_message("Calculated subclass using domain $domain is $calculated_subclass, " .
            "actual subclass is $subclass. This is bad!");
        return 0;
    }
    return 1;
}

1;

