package Genome::Reference;

class Genome::Reference {
    id_by => 'seq_id',
    table_name => 'GSC.reference_sequence_set reference_sequence_set',
    has => [
            description => {
                            is => 'Text',
                        },
            multi_fasta => {
                            is => 'Number',
                            len => 1,
                        },
            gsc_reference_set => {
                                  calculate_from => 'seq_id',
                                  calculate => q|
                                      return unless $seq_id;
                                      return GSC::Sequence::ReferenceSet->get($seq_id);
                                  |,
                              }
    ],
    has_many => [
                 members => {
                             is => 'Genome::Reference::Member',
                             reverse_id_by => 'reference',
                         },
             ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub bfa_directory {
    my $self = shift;
    my $db_type = 'maq binary fasta';
    my $gsc_ref_set = $self->gsc_reference_set;
    unless ($gsc_ref_set) {
        $self->error_message('Failed to get GSC::Sequence::ReferenceSet for seq_id '. $self->seq_id);
        return;
    }
    my $db = $gsc_ref_set->get_db($db_type);
    unless ($db) {
        unless ($gsc_ref_set->create_db($db_type)) {
            $self->error_message('Failed to create '. $db_type .' reference set db');
            return;
        }
        $db = $gsc_ref_set->get_db($db_type);
        unless ($db) {
            $self->error_message('Failed to get '. $db_type .' reference db after creating');
            return;
        }
    }
    return $db;
}

1;
