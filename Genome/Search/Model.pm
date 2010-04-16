package Genome::Search::Model;

use strict;
use warnings;

use Genome;

class Genome::Search::Model { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'model'
        }
    ]
};

sub _add_details_result_xml {
    my $class = shift;
    my $doc = shift;
    my $result_node = shift;
    
    my $xml_doc = $result_node->ownerDocument;
    
    my $model_id = $doc->value_for('id');
    
    my %info = $class->_get_info_hash($model_id);
    
    #Ensure the model still exists--otherwise just remove it from the index instead
    if(scalar keys %info == 0) {
        my $self = $class->_singleton_object;
        
        $self->_solr_server->delete_by_id($model_id);
        $self->warning_message('Removed nonexistent model with id #' . $model_id . ' from Solr index');
        
        return;
    }

    my $model = Genome::Model->get($model_id); #TODO Loading the model anyway defeats the speedup from caching the info hash.
    return unless $model; #Still in cache but deleted recently (#TODO Remove cache entry on delete)
    my @model_groups = $model->model_groups();

    if (@model_groups) {
        my @group_names = map { $_->name } @model_groups;
        my $model_group_text = join(', ', @group_names);
        my $model_groups_node = $result_node->addChild( $xml_doc->createElement("model-groups") );
        $model_groups_node->addChild( $xml_doc->createTextNode($model_group_text) );
    }

    my $model_url = "/cgi-bin/dashboard/status.cgi?genome-model-id=$model_id";
    my $model_url_node = $result_node->addChild( $xml_doc->createElement("url") );
    $model_url_node->addChild( $xml_doc->createTextNode($model_url) );

    my $subject_name_node = $result_node->addChild( $xml_doc->createElement("subject-name") );
    $subject_name_node->addChild( $xml_doc->createTextNode($info{'subject_name'}) );

    my $creation_date_node = $result_node->addChild( $xml_doc->createElement("creation-date") );
    $creation_date_node->addChild( $xml_doc->createTextNode($info{'creation_date'}) );

    my $user_name_node = $result_node->addChild( $xml_doc->createElement("user-name") );
    $user_name_node->addChild( $xml_doc->createTextNode($info{'user_name'}) );

    if ($model->is_default) {
        $result_node->addChild( $xml_doc->createAttribute("is-default",$model->is_default) );
    } else {
        $result_node->addChild( $xml_doc->createAttribute("is-default","0") );
    }

    if (defined $info{'last_complete_build_id'}) {
        $result_node->addChild( $xml_doc->createAttribute("has-last-complete-build","true") );
        my $last_complete_build_data_directory = $info{'last_complete_build_data_directory'};
        my $gold_snp_graph_url = $class->_get_gold_snp_graph_link(\%info, $model_id);
        my $data_directory_url = "https://gscweb/" . $last_complete_build_data_directory;

        my $last_complete_build_id_node = $result_node->addChild( $xml_doc->createElement("last-complete-build-id") );
        $last_complete_build_id_node->addChild( $xml_doc->createTextNode( $info{'last_complete_build_id'}  ) );

        my $summary_report_url_node = $result_node->addChild( $xml_doc->createElement("summary-report-url") );
        $summary_report_url_node->addChild( $xml_doc->createTextNode("https://gscweb.gsc.wustl.edu" . $last_complete_build_data_directory . "/reports/Summary/report.html") );

        my $gold_snp_graph_url_node = $result_node->addChild( $xml_doc->createElement("gold-snp-graph-url") );
        if ($gold_snp_graph_url) {
            $gold_snp_graph_url_node->addChild( $xml_doc->createTextNode($gold_snp_graph_url) );
            $gold_snp_graph_url_node->addChild( $xml_doc->createAttribute("has-gold-snp-graph","true") );
        } else {
            $gold_snp_graph_url_node->addChild( $xml_doc->createAttribute("has-gold-snp-graph","false") );
        }

        my $refcov_report_path = $last_complete_build_data_directory . "/reports/Reference_Coverage/report.html";
        #if (-e $refcov_report_path) {
            my $refcov_report_url = "https://gscweb.gsc.wustl.edu" . $last_complete_build_data_directory . "/reports/Reference_Coverage/report.html";

            my $refcov_report_url_node = $result_node->addChild($xml_doc->createElement("cdna-report-url"));
            $refcov_report_url_node->addChild($xml_doc->createTextNode($refcov_report_url));
        #}

        my $data_directory_url_node = $result_node->addChild( $xml_doc->createElement("data-directory-url") );
        $data_directory_url_node->addChild( $xml_doc->createTextNode($data_directory_url) );
    } else {
        $result_node->addChild( $xml_doc->createAttribute("has-last-complete-build","false") );
    }
    
    return $result_node;
}

sub generate_document {
    my $class = shift();
    my $model = shift();
    
    my $self = $class->_singleton_object;
    
    my $content = sprintf("%s %s", $model->processing_profile_name, $model->data_directory);
    #print $content, "\n";

    my %field_params = (class => ref($model),
                        title => $model->name,
                        id => $model->id,
                        timestamp => (defined $model->creation_date ? $model->creation_date : "1999-1-1 00:00:00 CST"),
                        content => (defined $content ? $content : ""),
                        type => $self->type,
    );

    my @fields;
    for (keys %field_params) {
            my $value = $field_params{$_};
            if ($_ eq "timestamp") {
                my ($a, $b) = split / /, $value; 
                $value = sprintf("%sT%sZ", $a, $b); 
            }
            push @fields, WebService::Solr::Field->new($_ => $value);
    }

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

sub _get_gold_snp_graph_link {
    my $class = shift;
    my $info = shift;
    my $model_id = shift;

    my $link;
    if (defined($info->{'gold_snp_het_metric_count'}) && $info->{'gold_snp_het_metric_count'} > 0) {
            $link = sprintf("/cgi-bin/dashboard/status.cgi?search_type=model_goldsnp_comparison&model-id-compare-1=" . $model_id)
    } else {
        return undef;
    }

    return $link;
}


sub _get_info_hash { #TODO Generalize memcached usage to all types
    my $class = shift;
    my $model_id = shift;
    
    my $self = $class->_singleton_object;
    my $memcache = $self->_memcache;

    my $model_key = 'search_model_metrics_' . $model_id;
    my $memcache_data = $memcache->get($model_key);

    if ($memcache_data) {
        return %{$memcache_data};
    }

    my $model = Genome::Model->get($model_id);
    
    return unless $model;

    my $last_build = $model->last_complete_build;
    my $last_build_data_dir;
    my $last_build_id;
    if ($last_build) {

         $last_build_data_dir = $last_build->data_directory;
         $last_build_id = $last_build->id;
    }


    my $model_data_dir = $model->data_directory;

    my @builds = $model->builds;

    my $metric_count;
    for (@builds) {
        $metric_count++ if ($_->get_metric('gold-heterozygous-snp match heterozygous-1-allele-variant filtered'));
    }

    my %store_hash;

    $store_hash{'gold_snp_het_metric_count'} = $metric_count;
    $store_hash{'last_complete_build_id'} = $last_build_id;
    $store_hash{'last_complete_build_data_directory'} = $last_build_data_dir;
    $store_hash{'data_directory'} = $model_data_dir;
    $store_hash{'subject_name'} = $model->subject_name;
    $store_hash{'user_name'} = $model->user_name;
    $store_hash{'creation_date'} = $model->creation_date;

    $memcache->set($model_key, \%store_hash);

    return %store_hash;

}

#OK!
1;
