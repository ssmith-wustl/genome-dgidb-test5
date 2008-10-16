package Genome::Model::Command::View::MetaGenomicCompositionMetrics;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Utility::IO::SeparatedValueReader;

class Genome::Model::Command::View::MetaGenomicCompositionMetrics {
    is => 'Command',
    #is => 'Genome::Model::Command',
    has => [
        processing_profile_name => {
            is => 'String', 
            doc => 'Processing profile name to get models',
        },
    ], 
};

sub help_brief {
    "MGC Metrics" 
}

sub help_detail {                        
    return <<"EOS"
EOS
}

sub execute {
    my $self = shift;

    my @models = Genome::Model->get(processing_profile_id => $self->processing_profile_id);
    unless ( @models ) {
        $self->error_message(
            sprintf('No models for processing profile name (%s)', $self->processing_profile_name) 
        );
        return;
    }

    my %metrics;
    for my $model ( @models ) {
        my $metrics_file = $model->metrics_file;
        unless ( -e $metrics_file ) {
            $self->error_message( sprintf('No metrics file for model (%s)', $model->name) );
            return;
        }
        my $svr = Genome::Utility::IO::SeparatedValueReader->new(
            input => $metrics_file,
        );
        my $metrics = $svr->next;
        if ( $svr->next ) { # should only be one metric!
            $self->error_message("Multiple metrics in file ($metrics_file)");
            return;
        }
        
        push @{$metrics{model}}, $model->name;
        for my $metric ( keys %$metrics ) {
            push @{$metrics{$metric}}, $metrics->{$metric};
        }
    }

    my @headers = sort { $a cmp $b } keys %metrics;
    print join(',', map { uc($_) } @headers),"\n";
    for my $index ( 0..$#models ) {
        print join(',', map { $metrics{$_}->[$index] } @headers),"\n";
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
