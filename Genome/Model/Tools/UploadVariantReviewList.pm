package Genome::Model::Tools::UploadVariantReviewList;

use strict;
use warnings;
use Data::Dumper;
use IO::File;
use Genome::VariantReviewDetail;
use Genome::VariantReviewListFilter;
use Genome::VariantReviewListMember;
use Genome::VariantReviewList;
use Genome::Utility::VariantReviewListReader;


use above "Genome";

UR::Object::Type->define(
    class_name => __PACKAGE__, is => 'Command',
    has => [
        list => {
            is => 'String',
            doc => 'Master csv to import', 
        },
        name => { 
            is => 'String', 
            doc => 'List name',
        },
    ],
    has_optional => [
        separation_character =>{
            is => 'String',
            doc => 'character or string that separates the fields in the list',
            default => '|',
        },
        author => { 
            is => 'String', 
            doc => 'Author or authors of the list',
        },
        filter => { 
            is => 'String', 
            doc => 'Filter, filters, or description of criteria use to generate the list',
        },
        rt_ticket => { 
            is => 'String', 
            doc => 'RT ticket id number',
        },
    ]
);

sub help_brief{
    return "Uploads a character delimited variant list to the db";
}

sub help_synopsis{
    return "gt upload-variant-review-list --list <list> --name <list_name> --author <list_author> --filter '<description of list criteria>'";
}

sub help_detail{
    return "This command takes in a character delimited list of variants, and uploads them to the data warehouse.  The separation character is the '|' char by default, but can be sspecified on the command line. The list should be formatted as follows:
chromosome|begin_position|end_position|variant_type|variant_length|delete_sequence|insert_sequence|genes|supporting_samples|supporting_dbs|finisher_manual_review|pass_manual_review|finisher_3730_review|manual_genotype_normal|manual_genotype_tumor|manual_genotype_relapse|somatic_status|notes

Once uploaded, the variants can be viewed and edited online at this address: https://gscweb.gsc.wustl.edu/view/variant_review_list.html
";
}

sub execute {
    my $self = shift;
    
    my $name = $self->name;
    my $filter = $self->filter || $name;
    my $author = $self->vtest($self->author);
    my $rt_ticket = $self->vtest($self->rt_ticket);
    my $separation_character = $self->separation_character;

    eval{

        my $review_list = Genome::VariantReviewList->get(name => $name);
        if ($review_list){
            $self->error_message("A list with this name($name) already exists in the DB! id:".$review_list->id);
            return;
        }else{
            
            $review_list = Genome::VariantReviewList->create(name => $name, author => $author, rt_ticket => $rt_ticket);
            my $review_list_filter = Genome::VariantReviewListFilter->create(filter_name => $filter, list_id => $review_list->id);
        }
        my $list_id = $review_list->id;
        my $list_reader = Genome::Utility::VariantReviewListReader->new($self->list, $separation_character);
        while (my $line_hash = $list_reader->next_line_data()){
            next if $line_hash->{header};

            my $current_member = Genome::VariantReviewDetail->get( begin_position => $line_hash->begin_position, chromosome => $line_hash->chromosome, end_position => $line_hash->end_position, variant_type => $line_hash->variant_type, delete_sequence => $line_hash->delete_sequence, insert_sequence_allele1 => $line_hash->insert_sequence_allele1, insert_sequence_allele2 => $line_hash->insert_sequence_allele2 );
            if ($current_member){
                my $new_notes = $self->vtest($current_member->notes);
                $new_notes .= ', ' if $new_notes and $line_hash->{notes};
                $new_notes .= $line_hash->{notes} if $line_hash->{notes};
                $current_member->notes($new_notes);
            }else{
                $current_member = Genome::VariantReviewDetail->create(
                   %$line_hash   
                );
            }
            my $member_id = $current_member->id;
            my $review_list_member = Genome::VariantReviewListMember->get_or_create(
                list_id => $list_id,
                member_id => $member_id,
            );

        }  #while ( my $line = getline);
    };

    if ($@){
        $self->error_message("error in execution. $@");
        return 0;
    }

=cut
# put this at the bottom
    unless(App::DB->sync_database) {
        $self->error_message("Failed to save GSC objects: " . App::DB->error_message);
        return;
    }
    $self->create_subscription("commit", 
        sub {  
            #App::DB->commit 
            print "committing!\n";
        }
    );
=cut

return 1;
}

sub vtest{
    my ($self, $v) = @_;
    return $v? $v : '';
}

1;
