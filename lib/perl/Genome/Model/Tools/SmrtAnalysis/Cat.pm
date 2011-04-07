package Genome::Model::Tools::SmrtAnalysis::Cat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::SmrtAnalysis::Cat {
    is  => ['Genome::Model::Tools::SmrtAnalysis::Base'],
    has_input => {
        input_file => { },
    },
    has_output => {
        contents => { is_optional => 1, },
    },
};

sub execute {
    my $self = shift;
    my $fh = IO::File->new($self->input_file,'r');
    my @contents = <$fh>;
    $fh->close;
    my $contents = join('',@contents);
    $self->contents($contents);
    print $self->contents ."\n";
    return 1;
}


1;
