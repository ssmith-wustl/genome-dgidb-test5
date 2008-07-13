
package Genome::Model::ShortRead;

use strict;
use warnings;

use Genome;

class Genome::Model::ShortRead {
    is => 'Genome::Model',
    has => [
        build_events  => {
            is => 'Genome::Model::Command::AddReads::PostprocessAlignments',
            reverse_id_by => 'model',
            is_many => 1,
            where => [
                parent_event_id => undef,
            ]
        },
        running_build_event => {
            calculate_from => ['assembly_event_arrayref'],
            calculate => q|
                my @e = sort { $a->id cmp $b->id } @$assembly_event_arrayref;
                my $e = $e[-1];
                #return if $e->event_status('Succeeded');
                return $e;
            |,
        }
    ],
    doc => 'A genome model produced by aligning DNA reads to a reference sequence.' 
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    if ($self->read_aligner_name eq 'newbler') {
        my $new_mapping = Genome::Model::Tools::454::Newbler::NewMapping->create(
                                                                            dir => $self->alignments_directory,
                                                                        );
        unless ($self->new_mapping) {
            $self->error_message('Could not setup newMapping for newbler in directory '. $self->alignments_directory);
            return;
        }
        my @fasta_files = grep {$_ !~ /all_sequences/} $self->get_subreference_paths(reference_extension => 'fasta');
        my $set_ref = Genome::Model::Tools::454::Newbler::SetRef->create(
                                                                    dir => $self->alignments_directory,
                                                                    reference_fasta_files => \@fasta_files,
                                                                );
        unless ($set_ref->execute) {
            $self->error_message('Could not set refrence setRef for newbler in directory '. $self->alignments_directory);
            return;
        }
    }
    return $self;
}

;
