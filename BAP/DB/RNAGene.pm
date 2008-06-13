package BAP::DB::RNAGene;

use base 'BAP::DB::DBI';


my $start_col = Class::DBI::Column->new('seq_start'   => { accessor => 'start' });
my $end_col   = Class::DBI::Column->new('seq_end'     => { accessor => 'end' });
my $desc_col  = Class::DBI::Column->new('description' => { accessor => 'desc' });


__PACKAGE__->table('rna_gene');
__PACKAGE__->columns(
                     'All' => qw(
                                 gene_id
                                 gene_name
                                 sequence_id
                                 acc
                                 strand
                                 score
                                 source
                                ),
                     $start_col,
                     $end_col,
                     $desc_col,
                    );
__PACKAGE__->sequence('gene_id_seq');

1;
