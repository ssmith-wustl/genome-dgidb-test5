package Genome::Model::Command::Report::Amplicons;

use strict;
use warnings;

use Genome;
use GSCApp;
use Command;

class Genome::Model::Command::Report::Amplicons
{
    is => 'Command',
    has => [
            sequence_item_name => {
                                   type => 'String',
                                   doc => 'The sequence item name',
                               },
        ],
};

sub help_brief {
    'a report generator for listing amplicon sequences from a sequence item'
}

sub help_synopsis {
    'genome-model report amplicons --sequence-item-nane'
}

sub help_detail {
    return <<EOS
given a sequence item from a pooled dna sample,
the generated report will include the amplicon sequences
EOS
}

sub execute { 
    my $self = shift;

    my $seq_item = GSC::Sequence::Item->get(sequence_item_name => $self->sequence_item_name);
    unless ($seq_item) {
        $self->error_message("Failed to find sequence item '$sequence_item_name'");
        return;
    }
    my $dna = GSC::PooledDNA->get(dna_name => $seq_item->sample_name);
    unless ($dna) {
        $self->error_message('Failed to find pooled dna for sample name '. $seq_item->sample_name);
        return;
    }
    my @pcr_setups = $dna->get_pcr_setups;
    unless (@pcr_setups) {
        $self->error_message('Failed to find pcr setups for dna '. $dna->dna_name);
        return;
    }
    for my $pcr_setup (@pcr_setups) {
        my $pcr_setup_with_info = GSC::PCRSetup->get_with_related_info(setup_id => $pcr_setup->setup_id);
        my $enzyme = $pcr_setup_with_info->{__enz__};
        my $primer_1 =$pcr_setup_with_info->{__pri_1__};
        my $primer_2 =$pcr_setup_with_info->{__pri_2__};
        my $ref_seq =$pcr_setup_with_info->{__ref_seq__};
        my $comment =$pcr_setup_with_info->{__comment__};
        print '>'. $pcr_setup_with_info->setup_name ."\n".
            $ref_seq->sequence_base_string ."\n";
    }
    return 1;
}

1;
