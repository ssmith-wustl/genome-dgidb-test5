package Genome::Model::DeNovoAssembly::Report::Summary;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::DeNovoAssembly::Report::Summary {
    is => 'Genome::Model::Report',
};

#< Generator >#
sub description {
    return 'Summary Report for '.
    Genome::Utility::Text::capitalize_words( $_[0]->build->description );
}

sub _add_to_report_xml {
    my $self = shift;

    my $build = $self->build
        or return;

    my %metrics = $build->set_metrics;
    unless ( %metrics ) {
        $self->error_message("Can't set metrics on ".$build->description);
        return;
    }
    
    $self->_add_dataset(
        name => 'metrics',
        row_name => 'metric',
        headers => [ 
            (map { s/_/\-/g; $_; } sort { $a cmp $b } keys %metrics), 
        ],
        rows => [[ 
            (map { $metrics{$_} } sort { $a cmp $b } keys %metrics),
        ]],
    ) or return;

    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/DeNovoAssembly/Report/Summary.pm $
#$Id: Summary.pm 59774 2010-06-09 23:46:44Z ebelter $
