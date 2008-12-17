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
        dev_flag         => {
                             is  => 'SCALAR',
                             doc => 'if true, connect to dev biosql',
                            },
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
    input        => [ 'bio_seq_features', 'dev_flag', 'biosql_namespace' ],
    output       => [ ],
    lsf_queue    => 'long',
    lsf_resource => 'rusage[tmp=100]'
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


    my $biosql_namespace = $self->biosql_namespace();
   
    my $dbadp;

    if ($self->dev_flag()) {
    
        $dbadp = Bio::DB::BioDB->new(
                                     -database => 'biosql',
                                     -user     => 'sg_user',
                                     -pass     => 'sgus3r',
                                     -dbname   => 'DWDEV',
                                     -driver   => 'Oracle',
                                    );
    
    }
    else {
        
        $dbadp = Bio::DB::BioDB->new(
                                     -database => 'biosql',
                                     -user     => 'sg_user',
                                     -pass     => 'sg_us3r',
                                     -dbname   => 'DWRAC',
                                     -driver   => 'Oracle',
                                    );
        
    }
    
    my $feature_adp = $dbadp->get_object_adaptor('Bio::SeqFeatureI');

    my $feature_query = Bio::DB::Query::BioQuery->new();
    
    $feature_query->datacollections(['Bio::SeqFeatureI f']);
    $feature_query->where(['f.display_name = ?']);

    my $seq_adp = $dbadp->get_object_adaptor('Bio::SeqI');

    my $seq_query = Bio::DB::Query::BioQuery->new();

    $seq_query->datacollections(['Bio::SeqI s']);
    $seq_query->where(["s.display_id = ?"]);

    my $interpro_count = 0;
    
    foreach my $ref (@{$self->bio_seq_features()}) {

        my @fixup = ( );

        if (ref($ref) eq 'ARRAY') {
            @fixup = @{$ref};
        }
        else {
            push @fixup, $ref;
            
        }

        my @features          = ( );
        my @interpro_features = ( );
        my %interpro_features = ( );
        
        FIXUP: foreach my $feature (@fixup) {

            ## Sanity Check!
            ## Due to some workflow funkiness related to 
            ## the conjoined cat seq feature operations
            ## we might see some undefined values...
            ## ...which we don't want to try and call
            ## methods on and such.  
            unless (defined($feature)) { next FIXUP; }
            
            my $source_tag = $feature->source_tag();

            ## Sort into two piles so as to be able to
            ## optimize the database activity.
            if (defined($source_tag) && ($source_tag eq 'InterPro')) {
                push @interpro_features, $feature;
            }
            else {
                push @features, $feature;
            }
            
        }

        @fixup = ( );
        
        INTERPRO: foreach my $feature (@interpro_features) {
            
            my $display_name = $feature->display_name();
            
            ##FIXME:  This is a lame, pathetic, fragile shortcut.
            my ($seq_id, $source, $number) = split /\./, $display_name;
            
            unless (defined($seq_id)) {
                warn "failed to parse seq_id from '$display_name'";
                next INTERPRO;
            }

            push @{$interpro_features{$seq_id}}, $feature;

        }

        SEQ: foreach my $seq_id (keys %interpro_features) {

            my $interpro_count = 0;
            
            my $result = $seq_adp->find_by_query(
                                                 $seq_query,
                                                 -name   => 'pap_upload_result_sequence',
                                                 -values => [ $seq_id ],
                                             );
            
            my $db_seq = $result->next_object();
            
            unless (defined($db_seq)) {
                warn "failed to find sequence object for '$seq_id'";
                next SEQ;
            }

            foreach my $feature (@{$interpro_features{$seq_id}}) {

                my $display_name = $feature->display_name();
                
                $interpro_count++;
                
                ## Change the name so we don't fetch it back below...
                $feature->display_name(join('.', $display_name, 'InterPro', $interpro_count));
                
                $db_seq->add_SeqFeature($feature);

            }
            
            $db_seq->store();
            
        }
        
        FEATURE: foreach my $feature (@features) {
              
              my $display_name = $feature->display_name();
              
              my $result = $feature_adp->find_by_query(
                                                       $feature_query,
                                                       -name   => 'pap_upload_result_feature',
                                                       -values => [ $display_name ],
                                                   );
              
              my $db_feature = $result->next_object();
              
              unless (defined($db_feature)) {
                  warn "failed to find feature object for '$display_name'";
                  next FEATURE;
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
                                      blastp_bit_score
                                      blastp_evalue
                                      blastp_percent_identical
                                      blastp_query_start
                                      blastp_query_end
                                      blastp_subject_start
                                      blastp_subject_end
                                      blastp_hit_name
                                      blastp_hit_description
                                      blastp_category
                                     )
                               ) {
                  
                  if ($feature->has_tag($tagname)) {
                      
                      my ($tagvalue) = $feature->each_tag_value($tagname);
                      $db_feature->add_tag_value($tagname, $tagvalue);
                      
                  }
                  
              }
              
              $db_feature->store();
              
          }
        
    }
    
    $feature_adp->commit();
    $seq_adp->commit();
    
    return 1;
    
}


1;
