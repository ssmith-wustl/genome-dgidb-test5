package Genome::Model::Tools::Db::AmpliconSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Db::AmpliconSummary {
    is => 'Command',
    has => [
            sample_name => {
                            type => 'String',
                            doc => 'The dna sample name',
                        },
            fasta_format => {
                             is => 'Boolean',
                             doc => 'This flag will print the full fasta sequence',
                             default_value => 0,
                         },
            output_file => {
                            is => 'String',
                            doc => 'The name of an output file to dump headers/sequences',
                        },
        ],
};

sub help_brief {
    'a report generator for listing amplicon sequences from a dna sample'
}

sub help_synopsis {
    'gmt db amplicon-summary --sample-name'
}

sub help_detail {
    return <<EOS
given a pooled dna sample name,
the generated report will include the amplicon sequences
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if (-e $self->output_file) {
        $self->error_message($self->output_file .' file already exists.');
        $self->delete;
        return;
    }
    return $self;
}

sub execute { 
    my $self = shift;

    my $dna = GSC::PooledDNA->get(dna_name => $self->sample_name);
    unless ($dna) {
        $self->error_message('Failed to find pooled dna for sample name '. $self->sample_name);
        return;
    }
    my @pcr_setups = $dna->get_pcr_setups;
    unless (@pcr_setups) {
        $self->error_message('Failed to find pcr setups for dna '. $dna->dna_name);
        return;
    }
    my $fh = IO::File->new($self->output_file,'w');
    for my $pcr_setup (@pcr_setups) {
        my $pcr_setup_with_info = GSC::PCRSetup->get_with_related_info(setup_id => $pcr_setup->setup_id);
        my $enzyme = $pcr_setup_with_info->{__enz__};
        my $primer_1 =$pcr_setup_with_info->{__pri_1__};
        my $primer_2 =$pcr_setup_with_info->{__pri_2__};
        my $ref_seq =$pcr_setup_with_info->{__ref_seq__};
        my $comment =$pcr_setup_with_info->{__comment__};
        my $chr = $ref_seq->get_subject;
        my $genome = $chr->get_genome;
        print $fh '>'. $pcr_setup_with_info->setup_name .' '. $genome->sequence_item_name .', Chr:'. uc($chr->chromosome)
            .', Coords '. $ref_seq->begin_position .'-'.$ref_seq->end_position .', Ori(+)'."\n";
        if ($self->fasta_format) {
            print $fh $ref_seq->sequence_base_string ."\n";
        }
    }
    $fh->close;
    return 1;
}

1;
