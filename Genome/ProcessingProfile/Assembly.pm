package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use Genome;

my @PARAMS = qw/
               read_filter
               read_filter_params
               read_trimmer
               read_trimmer_params
               assembler
               assembler_params
               sequencing_platform
              /;

class Genome::ProcessingProfile::Assembly{
    is => 'Genome::ProcessingProfile',
    has => [
            ( map { $_ => {
                           via => 'params',
                           to => 'value',
                           where => [name => $_],
                           is_mutable => 1
                       },
                   } @PARAMS
         ),
        ],
};

sub params_for_class {
    my $class = shift;
    return @PARAMS;
}

sub instrument_data_is_applicable {
    my $self = shift;
    my $instrument_data_type = shift;
    my $instrument_data_id = shift;
    my $subject_name = shift;

    my $lc_instrument_data_type = lc($instrument_data_type);
    if ($self->sequencing_platform) {
        unless ($self->sequencing_platform eq $lc_instrument_data_type) {
            $self->error_message('The processing profile sequencing platform ('. $self->sequencing_platform
                                 .') does not match the instrument data type ('. $lc_instrument_data_type);
            return;
        }
    }

    return 1;
}

1;

