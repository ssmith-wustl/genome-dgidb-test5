package Genome::Utility::MetagenomicClassifier::ChimeraClassification::Writer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Utility::MetagenomicClassifier::ChimeraClassification::Writer {
    is => 'Genome::Utility::IO::Writer',
    has_optional => [
        verbose => {
            type => 'BOOL',
            default => 0,
        },
        arff => {
            type => 'BOOL',
            default => 'false',
        },
        classification => {
            type => 'STRING',
            default => '?',
        },
    ],

};

sub write_one {
    my ($self, $classification) = @_;

    if ($self->verbose) {
        $self->_write_verbose($classification)
    }
    elsif ($self->arff) {
        $self->_write_arff($classification);
    }
    else {
        $self->_write_brief($classification);
    }
    return 1;
}

sub _rdp_writer {
    my $self = shift;
    my $rdp_writer = $self->{rdp_writer};
    unless ($rdp_writer) {
        $rdp_writer = Genome::Utility::MetagenomicClassifier::Rdp::Writer->create(output => $self->output)
    }
    return $rdp_writer;
}

sub write_arff_header {
    my $self = shift;
    my $output = $self->output;
    $output->print(
        '@relation test-weka.filters.unsupervised.attribute.NominalToString-C1

@attribute Name string
@attribute \'Common Depth\' numeric
@attribute \'Divergent Genera Count\' numeric
@attribute \'Percent Divergent Probes\' numeric
@attribute \'Classification Confidence\' numeric
@attribute \'Max Divergent Confidence Diff\' numeric
@attribute \'Min Convergent Confidence Diff\' numeric
@attribute classification {clean,unclassified,chimera}
@data'
    );
    $output->print("\n\n");
}

sub write_brief_header {
    my $self = shift;
    my $output = $self->output;
    $output->print("Name, Common Depth, Divergent Genera Count, Percent Divergent Probes, Classification Confidence, Max Divergent Confidence Diff, Max Convergent Confidence Diff\n");
}

sub _write_arff {
    my ($self, $classification) = @_;
    my $output = $self->output;
    $output->print($classification->name);
    $output->print(',');
    $output->print($classification->maximum_common_depth);
    $output->print(',');
    $output->print($classification->divergent_genera_count);
    $output->print(',');
    $output->print($classification->divergent_probe_percent);
    $output->print(',');
    $output->print($classification->classification->get_genus_confidence);
    $output->print(',');
    $output->print($classification->maximum_divergent_confidence_difference);
    $output->print(',');
    $output->print($classification->minimum_convergent_confidence_difference);
    $output->print(',');
    $output->print($self->classification);
    $output->print("\n");
}


sub _write_brief {
    my ($self, $classification) = @_;
    my $output = $self->output;
    $output->print($classification->name);
    $output->print(',');
    $output->print($classification->maximum_common_depth);
    $output->print(',');
    $output->print($classification->divergent_genera_count);
    $output->print(',');
    $output->print($classification->divergent_probe_percent);
    $output->print(',');
    $output->print($classification->classification->get_genus_confidence);
    $output->print(',');
    $output->print($classification->maximum_divergent_confidence_difference);
    $output->print(',');
    $output->print($classification->minimum_convergent_confidence_difference);
    $output->print("\n");
}

sub _write_verbose {
    my ($self, $classification) = @_;
    my $output = $self->output;
    my $rdp_writer = $self->_rdp_writer;

    $rdp_writer->write_one($classification->classification);

    my @probes = @{$classification->probe_classifications};
    foreach my $probe (@probes) {
        $output->print("\t");
        $rdp_writer->write_one($probe);
    }

    $output->print("\n");
}

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

Lynn Carmichael <lcarmich@watson.wustl.edu>

=cut

#$HeadURL: $
#$Id: $

