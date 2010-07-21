package Genome::Reference::Member;

class Genome::Reference::Member {
    id_by => ['seq_id','member_seq_id'],
    table_name => 'GSC.reference_sequence_set_member reference_sequence_set_member',
    has => [
            reference => {
                              is => 'Genome::Reference',
                              id_by => 'seq_id',
                          },
            sequence_item => {
                              calculate_from => 'member_seq_id',
                              calculate => q|
                                  return GSC::Sequence::Item->get($member_seq_id);
                              |,
                          },
            sequence_item_name => { via => 'sequence_item' },
            sequence_item_type => { via => 'sequence_item' },
            seq_length => { via => 'sequence_item' },
        ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
