#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 122;

use Bio::SeqIO;

BEGIN {
    use_ok('BAP::Job::Genemark');
    use_ok('BAP::Job::Glimmer');
    use_ok('BAP::Job::InterGenicBlastX');
    use_ok('BAP::Job::Phase2BlastP');
}

my @jobs = ( );

{
    
    my $fasta = Bio::SeqIO->new(
                                -file   => 'data/BACSTEFNL_Contig694.fasta',
                                -format => 'Fasta',
                            );
    
    my $seq = $fasta->next_seq();
 
    push @jobs, BAP::Job::Genemark->new(
                                        $seq,
                                        'data/heu_11_46.mod',
                                        2112,
                                    );
    
    push @jobs, BAP::Job::Glimmer->new(
                                       'glimmer2',
                                       $seq,
                                       'data/glimmer2.icm',
                                       undef,
                                       0,
                                       2112,
                                   );
    
    push @jobs, BAP::Job::Glimmer->new(
                                       'glimmer3',
                                       $seq,
                                       'data/glimmer3.icm',
                                       'data/glimmer3.pwm',
                                       0,
                                       2112,
                                   );
    
}

{

    my $fasta = Bio::SeqIO->new(
                                -file   => 'data/BACSTEFNL_Contig26.1.fasta',
                                -format => 'Fasta',
                            );
    
    my $seq = $fasta->next_seq();
    
    my @features = ( );
    
    my $gff = Bio::Tools::GFF->new(
                                   -file => 'data/BACSTEFNL_Contig26.1.gff',
                               );
    
    while (my $feature = $gff->next_feature()) {
        push @features, $feature;
    }
    
    my $blast_db = '/gscmnt/temp110/analysis/blast_nr/nr';
    
    push @jobs, BAP::Job::InterGenicBlastX->new(
                                                2112,
                                                $seq,
                                                \@features,
                                                $blast_db,
                                            );
   
    
    my $pep_fasta = Bio::SeqIO->new(
                                    -file   => 'data/BACSTEFNL_Contig694.pep.fasta',
                                    -format => 'Fasta',
                                );
    
    while (my $seq = $pep_fasta->next_seq()) {
        
        push @jobs, BAP::Job::Phase2BlastP->new(
                                                $seq,
                                                $blast_db,
                                                2112
                                            );
        
    }
    
}

foreach my $job (@jobs) {
    
    isa_ok($job, 'GAP::Job');
    can_ok($job, qw(execute execution_host));

    $job->execute();

    isnt($job->execution_host(), 'unknown');

    my $job_class = ref($job);

    if ($job_class eq 'BAP::Job::Phase2BlastP') {
        
        my $evidence_ref = $job->evidence();
        
        isa_ok($evidence_ref, 'HASH');
        
        ok(exists($evidence_ref->{$job->seq->display_id()}));
        
    }

    else {

        my @genes = ( );

        if ($job_class eq 'BAP::Job::InterGenicBlastX') {
            @genes = @{$job->genes()};
        }
        else {
            @genes = $job->seq->get_SeqFeatures(); 
        }
        
        foreach my $gene (@genes) {
            
            if (ref($job) eq 'BAP::Job::Genemark') {
                isa_ok($gene,'Bio::Tools::Prediction::Gene');
            }
            else {
                isa_ok($gene, 'Bio::SeqFeature::Generic');
            }
        }
        
    }

}

unlink('error.log');
