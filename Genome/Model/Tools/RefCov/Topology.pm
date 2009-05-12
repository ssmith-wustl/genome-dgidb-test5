package Genome::Model::Tools::RefCov::Topology;

use strict;
use warnings;

use Genome;

use RefCov::Reference;

class Genome::Model::Tools::RefCov::Topology {
    is => ['Command'],
    has_input => [
            frozen_file => {
                            is => 'Text',
                        },
             output_file => {
                             is => 'Text',
                             is_optional => 1,
                         }
              ],
};

sub execute {
    my $self = shift;
    unless(Genome::Utility::FileSystem->validate_file_for_reading($self->frozen_file)) {
        $self->error_message('Failed to valide frozen file '. $self->frozen_file .' for reading!');
        return;
    }
    if ($self->output_file) {
        my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_file);
        unless ($output_fh) {
            $self->error_message('Failed to open output file '. $self->output_file .' for writing!');
            return;
        }
        my $tee_fh = IO::Tee->new(\*STDOUT,$output_fh);
    }
    my $myRef = RefCov::Reference->new( thaw => $self->frozen_file )->print_topology();
    return 1;
}
