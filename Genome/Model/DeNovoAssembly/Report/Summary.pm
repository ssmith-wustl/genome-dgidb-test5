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

    my $stats_file = $build->stats_file;
    my $stats_fh = Genome::Utility::FileSystem->open_file_for_reading($stats_file);
    unless ( $stats_fh ) {
        $self->error_message("Can't open stats file ($stats_file)");
        return;
    }
    
    my @interesting_metric_names = $build->interesting_metric_names;
    while ( my $line = $stats_fh->getline ) {
        next unless $line =~ /\:/;
        chomp $line;
        my ($metric, $value) = split(/\:\s+/, $line);
        $metric = lc $metric;
        next unless grep { $metric eq $_ } @interesting_metric_names;
        $value =~ s/\s.*$//;
        unless ( defined $value ) {
            $self->error_message("Found metric ($metric) in stats file, but it does not have a vlue ($line)");
            return;
        }
        my $metric_method = join('_', split(/\s/, $metric));
        $build->$metric_method($value);
    }
    
    $self->_add_dataset(
        name => 'metrics',
        row_name => 'metric',
        headers => [ 
            (map { join('-', split(/\s/)) } @interesting_metric_names), 
            'estimated-read-length',
        ],
        rows => [[ 
            (map { $build->$_ } map { join('_', split(/\s/)) } @interesting_metric_names), 
            $build->estimate_average_read_length,
        ]],
    ) or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
