package MGAP::Command::UploadResult;

use strict;
use warnings;

use BAP::DB::SequenceSet;
use BAP::DB::Sequence;
use BAP::DB::tRNAGene;
use Workflow;

class MGAP::Command::UploadResult {
    is => ['MGAP::Command'],
    has => [
        dev => { is => 'SCALAR', doc => "if true set $BAP::DB::DBI::db_env = 'dev'" },
        seq_set_id => { is => 'SCALAR', doc => 'identifies a whole assembly' },
        bio_seq_features => { is => 'ARRAY', doc => 'array of Bio::Seq::Feature' },
    ],
};

operation MGAP::Command::UploadResult {
    input  => [ 'bio_seq_features' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;
    
    
    if ($self->dev()) {
        $BAP::DB::DBI::db_env = 'dev'; 
    }
    
    my $sequence_set_id = $self->seq_set_id();

    my $sequence_set = BAP::DB::SequenceSet->retrieve($sequence_set_id);

    my @sequences = $sequence_set->sequences();

    foreach my $sequence (@sequences) {

        my @coding_genes = $sequence->coding_genes();
        my @trna_genes   = $sequence->trna_genes();
        my @rna_genes    = $sequence->rna_genes();
        
        foreach my $gene (
                          @coding_genes,
                          @trna_genes,
                          @rna_genes
                      ) { $gene->delete(); }
        
    }
    
    my %features   = ( );
    my %gene_count = ( );
    
    foreach my $feature (@{$self->bio_seq_feature()}) {
        push @{$features{$feature->seq_id()}}, $feature;
    }
    
    foreach my $seq_id (keys %features) {

        $gene_count{$seq_id} = 0;
        
        my $sequence = BAP::DB::Sequence->retrieve(
                                                   sequence_set_id => $sequence_set_id,
                                                   sequence_name   => $seq_id,
                                               );
        
        my @features = @{$features{$seq_id}};
        
        foreach my $feature (@features) {
            
            my $source = $feature->source_tag();
            
            if ($source eq 'trnascan') {
                
                my $gene_name = join('.', $seq_id, (join('', 't', $gene_count{$seq_id})));
                my ($codon)   = $feature->each_tag_value('Codon');
                my ($aa)      = $feature->each_tag_value('AminoAcid');
                
                BAP::DB::tRNAGene->insert({
                                           gene_name   => $gene_name,
                                           sequence_id => $sequence->sequence_id(),
                                           start       => $feature->start(),
                                           end         => $feature->end(),
                                           strand      => $feature->strand(),
                                           source      => $source,
                                           score       => $feature->score(),
                                           codon       => $codon,
                                           aa          => $aa,
                                       });
                
            }
            
        }
        
    }
    
    return 1;
    
}

1;
