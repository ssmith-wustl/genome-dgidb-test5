#!/gsc/bin/perl

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-db';

use strict;
use warnings;

use Bio::Seq;
use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;

use Data::Dumper;

my $dbadp = Bio::DB::BioDB->new(
                                -database => 'biosql',
                                -user     => 'sg_user',
                                -pass     => 'sgus3r',
                                -dbname   => 'DWDEV',
                                -driver   => 'Oracle'
                            );

my $adp = $dbadp->get_object_adaptor("Bio::SeqI");

my $query = Bio::DB::Query::BioQuery->new();

$query->datacollections([
                         "Bio::PrimarySeqI s",
                        ]);

$query->where(["s.display_id like '$ARGV[0]%'"]);

my $result = $adp->find_by_query($query);

while (my $seq = $result->next_object()) {

    my $gene_name = $seq->display_name();
    
    my @features = $seq->get_SeqFeatures();

    #print qq{Sequence : "$gene_name"}, "\n";

    foreach my $feature (@features) {

        my $display_name = $feature->display_name();
        
        if (
            $feature->has_tag('psort_localization') &&
            $feature->has_tag('psort_score')
           ) {

            print qq{Sequence $display_name}, "\n";

            my ($psort_localization) = $feature->each_tag_value('psort_localization');
            my ($psort_score)        = $feature->each_tag_value('psort_score');
            
            print qq{PSORT_B $psort_localization $psort_score}, "\n";

        }
        
        my $annotation_collection = $feature->annotation();

        my @annotations = $annotation_collection->get_Annotations();

        my @dblinks = grep { $_->isa('Bio::Annotation::DBLink') } @annotations;
 
 
        my @kegg_dblinks = grep { $_->database() eq 'KEGG' } @dblinks;

        my ($gene_dblink)      = grep { $_->primary_id() =~ /\w{3}\:\w+/ } @kegg_dblinks;
        my ($orthology_dblink) = grep { $_->primary_id() =~ /^K\d+$/   } @kegg_dblinks;

        if (
            $feature->has_tag('kegg_evalue') &&
            $feature->has_tag('kegg_description') &&
            defined($gene_dblink) &&
            defined($orthology_dblink)
           ) {
           
             my $gene_id            = $gene_dblink->primary_id();
             my $orthology_id       = $orthology_dblink->primary_id();
             my ($kegg_evalue)      = $feature->each_tag_value('kegg_evalue');
             my ($kegg_description) = $feature->each_tag_value('kegg_description');
             
             print qq{KEGG   "$gene_id $kegg_evalue $kegg_description $orthology_id"}, "\n";   

        }
        
        my @interpro_dblinks = grep { $_->database() eq 'InterPro' } @dblinks;
        
        foreach my $dbl (@interpro_dblinks) {

            my $ipr = $dbl->primary_id();
            
            print qq{Interpro   "HMMPfam : $ipr"}, "\n";

        }

        #my @genbank_dblinks = grep { $_->database() eq 'GenBank' } @dblinks;

        #foreach my $dbl (@genbank_dblinks) {

        #    my $id      = $dbl->primary_id();
            
            #print qq{$id}, "\n";

        #}

    }
    
}
