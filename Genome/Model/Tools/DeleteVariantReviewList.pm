package Genome::Model::Tools::DeleteVariantReviewList;

use strict;
use warnings;

use above 'Genome';

UR::Object::Type->define(
    class_name => __PACKAGE__, is => 'Command',
    has => [
        db_list_name =>{
            is          => 'String',
            doc         => 'Name of list to be deleted',
            is_optional => 1,
        },
        db_list_id => { 
            is          => 'String', 
            doc         => 'ID of list to be deleted',
            is_optional => 1,
        },
    ]
);

sub help_brief{
    return "Delete a variant review list";
}

sub help_synopsis{
    return "gt delete-variant-review-list --db-list-name <list-name>";
}

sub help_detail{
"Delete a variant review list.";
}


sub execute{
    my ($self) = @_;
    my $db_list = Genome::VariantReviewList->get($self->db_list_name ? (name=>$self->db_list_name) : (id=>$self->db_list_id)); 
    
    unless ($db_list){
        $self->error_message("List doesn't exist");
        return 0;
    }
    
    my @db_list_members = Genome::VariantReviewListMember->get(list_id=>$db_list->id);    
    foreach (@db_list_members){
        my $detail = Genome::VariantReviewDetail->get(id=>$_->member_id);
        my @test_members = Genome::VariantReviewListMember->get(member_id=>$detail->id);
        if (@test_members > 1){
           my %list_id_hash; 
           foreach (@test_members){
                $list_id_hash{$_->list_id}++;
            }
            if (scalar keys %list_id_hash == 1){
                $detail->delete;
            }
        }else {
            $detail->delete;
        }

        $_->delete;
        
    }
    $db_list->delete;    
}

1;
