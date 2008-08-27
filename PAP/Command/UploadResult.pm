#$Id$

package PAP::Command::UploadResult;

use strict;
use warnings;

use Workflow;

use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;


class PAP::Command::UploadResult {
    is  => ['PAP::Command'],
    has => [
        biosql_namespace => { 
                             is  => 'SCALAR', 
                             doc => 'biosql namespace'           
                            },
        bio_seq_features => { 
                              is  => 'ARRAY',
                              doc => 'array of Bio::Seq::Feature' 
                            },
    ],
};

operation PAP::Command::UploadResult {
    input  => [ 'bio_seq_features', 'biosql_namespace' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Store input gene predictions in the BioSQL schema using the specified namespace";
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


    my $biosql_namespace = 'biosql_namespace';
    
    my $dbadp = Bio::DB::BioDB->new(
                                    -database => 'biosql',
                                    -user     => 'sg_user',
                                    -pass     => 'sgus3r',
                                    -dbname   => 'DWDEV',
                                    -driver   => 'Oracle',
                                );
    
    my $adp = $dbadp->get_object_adaptor('Bio::SeqFeatureI');

    my $query = Bio::DB::Query::BioQuery->new();
    
    $query->datacollections(['Bio::SeqFeatureI f']);
    $query->where(['f.display_name = ?']);
    
    foreach my $ref (@{$self->bio_seq_features()}) {

        foreach my $feature (@{$ref}) {

            my $display_name = $feature->display_name();
            
            my $result = $adp->find_by_query(
                                             $query,
                                             -name   => 'pap_upload_result',
                                             -values => [ $display_name ]
                                         );
            
            my $db_feature = $result->next_object();
            
            unless (defined($db_feature)) {
                warn "failed to find feature object for '$display_name'";
                next;
            }

            my $feature_ac    = $feature->annotation();
            my $db_feature_ac = $db_feature->annotation();

            foreach my $annotation ($feature_ac->get_Annotations()) {

                $db_feature_ac->add_Annotation($annotation);
                
            }

            foreach my $tagname (
                                 qw(
                                    psort_localization 
                                    psort_score
                                    kegg_evalue
                                    kegg_description
                                   )
                                ) {
                
                if ($feature->has_tag($tagname)) {
                
                    my ($tagvalue) = $feature->each_tag_value($tagname);
                    $db_feature->add_tag_value($tagname, $tagvalue);
                    
                }
                
            }
            
        }
        
    }

    $adp->rollback();
    
    return 1;
    
}


1;
