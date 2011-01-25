package Genome::Model::Tools::OldRefCov::Topology;

use strict;
use warnings;

use Genome;

use RefCov::Reference;
use Statistics::R;

class Genome::Model::Tools::OldRefCov::Topology {
    is => ['Command'],
    has_input => [
                  frozen_file => {
                                  is => 'Text',
                                  doc => 'The frozen reference file produed by ref-cov.  ex: __SAT1.rc',
                              },
                  output_file => {
                                  is => 'Text',
                                  doc => 'The output file path to dump the results',
                                  is_optional => 1,
                              },
                  graph => {
                            is => 'Boolean',
                            doc => 'Creates a png format line graph',
                            default_value => 0,
                        },
              ],
};

sub execute {
    my $self = shift;
    unless(Genome::Sys->validate_file_for_reading($self->frozen_file)) {
        $self->error_message('Failed to validate frozen file '. $self->frozen_file .' for reading!');
        return;
    }
    my $oldout;
    if ($self->output_file) {
        open $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
        my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
        unless ($output_fh) {
            $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
            return;
        }
        STDOUT->fdopen($output_fh,'w');
    }
    my $myRef = RefCov::Reference->new( thaw => $self->frozen_file )->print_topology();
    if ($self->graph) {
        my $graph = GD::Graph::lines->new();
        $graph->set(
                    'x_label' => 'Base Pair Position',
                    'x_label_skip' => 1000,
                    'y_label' => 'Read Depth',
                    'title' => $myRef->name .' Topology',
                    marker_size => 1,
                );
        my $start = $myRef->start;
        my $stop = $myRef->stop;
        my @positions = ($start .. $stop);
        my @data = (\@positions,$myRef->depth_span(start => $start,stop=> $stop));
        my $gd = $graph->plot(\@data);
        open(IMG, '>'. ($self->output_file || 'topology') .'.png') or die $!;
        binmode IMG;
        print IMG $gd->png;
        close IMG;
    }
    if ($oldout) {
        open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    }
    return 1;
}
