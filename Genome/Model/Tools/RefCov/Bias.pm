package Genome::Model::Tools::RefCov::Bias;

use strict;
use warnings;

use Genome;

use RefCov::Reference;

class Genome::Model::Tools::RefCov::Bias {
    is => ['Command'],
    has_input => [
                  frozen_directory => {
                                       is => 'Text',
                                       doc => 'The frozen reference directory produed by ref-cov.',
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
    unless(Genome::Utility::FileSystem->validate_directory_for_read_access($self->frozen_directory)) {
        $self->error_message('Failed to validate frozen directory '. $self->frozen_directory .' for read access!');
        return;
    }
    my $oldout;
    if ($self->output_file) {
        open $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
        my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_file);
        unless ($output_fh) {
            $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
            return;
        }
        STDOUT->fdopen($output_fh,'w');
    }
    my $dh = Genome::Utility::FileSystem->open_directory($self->frozen_directory);
    unless ($dh) {
        $self->error_message('Failed to acquire directory handle for frozen directory '. $self->frozen_directory .":  $!");
        return;
    }

    my @gene_files = map { $self->frozen_directory .'/'. $_  } grep { /^\_\_.*\.rc/ } $dh->read;
    my %relative_depth;
    my $gene_counter = 0;
    for my $gene_file (@gene_files) {
        if (($gene_counter % 1000) == 0) {
            $self->status_message('Finished thawing '. $gene_counter .' gene files out of '. scalar(@gene_files) .'...');
        }
        unless ($gene_file =~ /\/\_\_(.*)\.rc/) {
            $self->error_message('Failed to parse gene file name '. $gene_file);
            return;
        }
        my $gene = RefCov::Reference->new( thaw => $gene_file );
        my $depth_span_ref = $gene->depth_span(
                                               start => $gene->start,
                                               stop => $gene->stop,
                                           );
        my @depth_span = @{$depth_span_ref};
        unless (scalar(@depth_span) == $gene->reflen) {
            $self->error_message('The length of the gene '. $gene->reflen .' does not match the depth span '. scalar(@depth_span) );
            return;
        }
        my $pos = 1;
        for (@depth_span) {
            my $relative_position = sprintf("%.02f",($pos / $gene->reflen));
            if ($relative_position > 1) {
                $self->error_message('Relative position '. $relative_position .' for gene '. $gene->name .' is greater than one.');
                return;
            }
            $relative_depth{$relative_position} += $_;
            $pos++;
        }
        $gene_counter++;
    }
    my @positions = grep { $_ <= 1 } sort {$a <=> $b} keys %relative_depth;
    my @depth;
    for my $position (@positions) {
        print $position ."\t". $relative_depth{$position} ."\n";
        push @depth, $relative_depth{$position};
    }
    if ($self->graph) {
        my @data = (\@positions,\@depth);
        my $graph = GD::Graph::lines->new(1200,800);
        $graph->set(
                    'x_label' => "Relative Position 5'->3'",
                    'x_label_skip' => 10,
                    'y_label' => 'Read Depth',
                    'title' => "5'->3' Bias Topology",
                    marker_size => 1,
                );
        my $gd = $graph->plot(\@data);
        open(IMG, '>'. ($self->output_file || 'topology') .'.png' ) or die $!;
        binmode IMG;
        print IMG $gd->png;
        close IMG;
    }
    if ($oldout) {
        open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    }
    return 1;
}
