use strict;
use warnings;

use lib '/gscuser/mjohnson/bioperl-svn/bioperl-live';
use lib '/gscuser/mjohnson/bioperl-svn/bioperl-run';

use Workflow;

use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;
use Bio::Seq;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;

use Data::Dumper;
use File::Temp;
use Test::More tests => 4;

BEGIN {
    use_ok('PAP::Command');
    use_ok('PAP::Command::UploadResult');
}

my $biosql_namespace = 'AUTOMATED_TEST';

my $db_adp = connect_db();

my $seq_adp = $db_adp->get_object_adaptor('Bio::Seq');

my $bp_seq = create_seq($biosql_namespace);

my $pseq = $db_adp->create_persistent($bp_seq);

$pseq->store();
$seq_adp->commit();

my $feature_ref = create_feature_ref();

my $command = PAP::Command::UploadResult->create();

$command->biosql_namespace($biosql_namespace);
$command->bio_seq_features($feature_ref);

isa_ok($command, 'PAP::Command::UploadResult');

ok($command->execute());


$seq_adp->rollback();

$pseq->remove();
$seq_adp->commit();

sub connect_db {
    
    return Bio::DB::BioDB->new(
                               -database => 'biosql',
                               -user     => 'sg_user',
                               -pass     => 'sgus3r',
                               -dbname   => 'DWDEV',
                               -driver   => 'Oracle',
                           );
    
}

sub create_seq {

    my ($namespace) = @_;

    
    my $seq = Bio::Seq->new(
                            -id               => 'TST0001',
                            -accession_number => '999999999', 
                            -namespace        => $namespace,
                            -seq              => 'GATTACA' x 1000, 
                           );
    
    $seq->add_SeqFeature(
                         Bio::SeqFeature::Generic->new(
                                                       -seq_id       => 'TST0001',
                                                       -display_name => 'TST0001.GeneMark.1',
                                                       -primary      => 'gene',
                                                       -source       => 'genemark',
                                                       -start        => 1,
                                                       -end          => 1000,
                                                       -strand       => 1,
                                                      )
                        );

    return $seq;
    
}

sub create_feature_ref {

    my $bsg = Bio::SeqFeature::Generic->new(
                                            -display_name => 'TST0001.GeneMark.1',
                                           );
    
    $bsg->annotation->add_Annotation(
                                     'dblink',
                                     Bio::Annotation::DBLink->new(
                                                                  -database   => 'KEGG',
                                                                  -primary_id => 'psp:PSPPH_2639',
                                                                 ),
                                    );

    $bsg->annotation->add_Annotation(
                                     'dblink',
                                     Bio::Annotation::DBLink->new(
                                                                  -database   => 'KEGG',
                                                                  -primary_id => 'K00435',
                                                                 ),
                                    );

    $bsg->annotation->add_Annotation(
                                     'dblink',
                                     Bio::Annotation::DBLink->new(
                                                                  -database   => 'GenBank',
                                                                  -primary_id => 'YP_001300340.1',
                                                              ),
                                 );


    return [ [ $bsg ] ];

}
