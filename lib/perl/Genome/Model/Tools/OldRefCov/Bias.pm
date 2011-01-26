package Genome::Model::Tools::OldRefCov::Bias;

use strict;
use warnings;

use Genome;

use RefCov::Reference;
use GD::Graph::lines;

class Genome::Model::Tools::OldRefCov::Bias {
    is => ['Command'],
    has => [
            frozen_directory => {
                                 is => 'Text',
                                 doc => 'The frozen reference directory produed by ref-cov.',
                             },
            output_file => {
                            is => 'Text',
                            doc => 'The output file path to dump the results',
                        },
        ],
    has_optional => [

                     image_file => {
                                    is => 'Text',
                                    doc => 'The output png file path to dump the graph',
                                    is_optional => 1,
                                },
                     sample_name => {
                                     is => 'Text',
                                     default_value => '',
                                 },
                 ],
};

sub execute {
    my $self = shift;
    unless(Genome::Sys->validate_directory_for_read_access($self->frozen_directory)) {
        $self->error_message('Failed to validate frozen directory '. $self->frozen_directory .' for read access!');
        return;
    }
    my $dh = Genome::Sys->open_directory($self->frozen_directory);
    unless ($dh) {
        $self->error_message('Failed to acquire directory handle for frozen directory '. $self->frozen_directory .":  $!");
        return;
    }

    my @ref_files = map { $self->frozen_directory .'/'. $_  } grep { /^\_\_.*\.rc/ } $dh->read;
    my %size_to_relative_depth;
    my $ref_counter = 0;
    for my $ref_file (@ref_files) {
        if (($ref_counter % 1000) == 0) {
            $self->status_message('Finished thawing '. $ref_counter .' ref files out of '. scalar(@ref_files) .'...');
        }
        unless ($ref_file =~ /\/\_\_(.*)\.rc/) {
            $self->error_message('Failed to parse ref file name '. $ref_file);
            return;
        }
        my $ref = RefCov::Reference->new( thaw => $ref_file );
        my $length = $ref->reflen;
        my $size;
        if (($length >= 100) && ($length <= 2_999)) {
            $size = 'SMALL';
        }
        elsif (($length >= 3_000) && ($length <= 6_999)) {
            $size = 'MEDIUM';
        }
        elsif (($length >= 7_000)) {
            $size = 'LARGE';
        } else { next; }
        my $depth_span_ref = $ref->depth_span(
                                               start => $ref->start,
                                               stop => $ref->stop,
                                           );
        my @depth_span = @{$depth_span_ref};
        unless (scalar(@depth_span) == $length) {
            $self->error_message('The length of the ref '. $length .' does not match the depth span '. scalar(@depth_span) );
            return;
        }
        my $pos = 1;
        for (@depth_span) {
            my $relative_position = sprintf("%.02f",($pos / $length));
            if ($relative_position > 1) {
                $self->error_message('Relative position '. $relative_position .' for ref '. $ref->name .' is greater than one.');
                return;
            }
            $size_to_relative_depth{$size}{$relative_position} += $_;
            $pos++;
        }
        $ref_counter++;
    }
    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
        return;
    }
    foreach my $size (keys %size_to_relative_depth){
        my %relative_depth = %{$size_to_relative_depth{$size}};
        my @positions = grep { $_ <= 1 } sort {$a <=> $b} keys %relative_depth;
        my @depth;
        print $output_fh "#$size\n";
        for my $position (@positions) {
            print $output_fh $position ."\t". $relative_depth{$position} ."\n";
            push @depth, $relative_depth{$position};
        }
        if ($self->image_file) {
            my ($filename, $dirname, $suffix) = File::Basename::fileparse($self->image_file,'.png');
            my $image_file = $dirname . $filename .'_'. $size . $suffix;
            my @data = (\@positions,\@depth);
            my $graph = GD::Graph::lines->new(1200,800);
            $graph->set(
                        'x_label' => "Relative Position 5'->3'",
                        'x_label_skip' => 10,
                        'y_label' => 'Read Depth',
                        'title' => $self->sample_name ." $size Reference 5'->3' Bias ",
                        marker_size => 1,
                    );
            my $gd = $graph->plot(\@data);
            open(IMG, '>'. $image_file) or die $!;
            binmode IMG;
            print IMG $gd->png;
            close IMG;
        }
    }
    $output_fh->close;
    return 1;
}
