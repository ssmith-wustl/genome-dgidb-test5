package Genome::Model::Tools::AddVariantsToList;

use strict;
use warnings;
use Genome::Utility::VariantReviewListReader;


use above 'Genome';

UR::Object::Type->define(
    class_name => __PACKAGE__, is => 'Command',
    has => [
        list => {
            is => 'String',
            doc => 'Master csv to update from', 
        },
    ],
    has_optional => [
        db_list_name =>{
            is => 'String',
            doc => 'Name of list to be updated',
        },
        db_list_id => { 
            is => 'String', 
            doc => 'ID of list to be updated',
        },
        separation_character => {
            is => 'String',
            doc => 'separation character in list of variants to be added',
        },
    ]
);

sub help_brief{
    return "Add new variants to an existing list";
}

sub help_synopsis{
    return "gt add-variants-to-list --list <list> --db_list_id <id>";
}

sub help_detail{
"Adds variants to existing lists given the list name or list id. The list must be a character delimited list.  The default delimiter is the '|' char, but this can be specified on the command line.  The list columns must be in the following format:\n".join('|', Genome::Utility::VariantReviewListReader->list_columns)."\n Once uploaded, the variants can be viewed and edited online at this address: https://gscweb.gsc.wustl.edu/view/variant_review_list.html";
}

sub execute{
    my $self = shift;
    my $list = Genome::Utility::VariantReviewListReader->new($self->list, $self->separation_character);
    my $db_list = Genome::VariantReviewList->get($self->db_list_name ? (name=>$self->db_list_name) : (id=>$self->db_list_id)); 

    unless ($db_list){
        $self->error_message("List doesn't exist");
        return 0;
    }
    my $list_id = $db_list->id;
    while (my $line_hash = $list->next_line_data()){
        last unless $line_hash;
        next if $line_hash->{header};

        my $current_member = Genome::VariantReviewDetail->get( begin_position => $line_hash->{begin_position}, chromosome => $line_hash->{chromosome}, end_position => $line_hash->{end_position}, variant_type => $line_hash->{variant_type}, delete_sequence => $line_hash->{delete_sequence}, insert_sequence_allele1 => $line_hash->{insert_sequence_allele1}, insert_sequence_allele2 => $line_hash->{insert_sequence_allele2} );
        if ($current_member){
            $self->status_message("Member found, skipping");
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

}
1;
