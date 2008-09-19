package Genome::Model::Tools::ManualReview::UploadVariantReviewList;

use strict;
use warnings;
use Data::Dumper;
use IO::File;
use Genome::Utility::VariantReviewListReader;

use Genome;

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
    return "gt manual-review upload-variant-review-list --list <list> --name <list_name> --author <list_author> --filter '<description of list criteria>'";
}

sub help_detail{
    return "This command takes in a character delimited list of variants, and uploads them to the data warehouse.  The separation character is the '|' char by default, but can be specified on the command line. The list should be formatted as follows:\n".join('|', Genome::Utility::VariantReviewListReader->list_columns)."\n Once uploaded, the variants can be viewed and edited online at this address: https://gscweb.gsc.wustl.edu/view/variant_review_list.html
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
            last unless $line_hash;
            next if $line_hash->{header};

            my $current_member = Genome::VariantReviewDetail->get( begin_position => $line_hash->{begin_position}, chromosome => $line_hash->{chromosome} );

            my $info;
            if ($current_member){
                $info.="Current member found: ".$current_member->chromosome.", ".$current_member->begin_position."\n";
                #notes
                my $new_notes = $self->vtest($current_member->notes);
                $new_notes .= ', ' if $new_notes and $line_hash->{notes};
                $new_notes .= $line_hash->{notes} if $line_hash->{notes};
                $current_member->notes($new_notes);
                #genes
                my $current_genes = $current_member->genes;
                my @current_genes;
                @current_genes = split(/[,\/]/, $current_genes) if $current_genes;
                my $new_genes = $line_hash->{genes};
                my @new_genes;
                @new_genes = split(/[,\/]/, $new_genes) if $new_genes;
                my @genes_to_add;
                foreach my $new_gene (@new_genes){
                    my $found = 0;
                    foreach my $current_gene (@current_genes){
                        $found++ if $new_gene =~ /$current_gene/i;
                    }
                    push @genes_to_add, $new_gene unless $found;
                }
                if (@genes_to_add){
                    $info .= "adding genes ".join(" ", @genes_to_add)."\n";
                }
                my @genes = (@current_genes, @genes_to_add);
                $current_member->genes(join(",", @genes));
                #rest
                foreach my $col (keys %$line_hash){
                    next if $col =~ /genes|notes/;
                    my $current_val = $current_member->$col;
                    my $new_val = $line_hash->{$col};
                    if ($current_val){
                        if ($new_val){
                            if ($current_val ne $new_val){
                                $current_member->$col("DISCREPANCY($current_val : $new_val");
                                $info .= "discrepancy at $col : $current_val || $new_val\n";
                            }
                        }
                    }elsif ($new_val){
                        $current_member->$col($new_val);
                    }
                }
                print $info;
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

    return 1;
}

sub vtest{
    my ($self, $v) = @_;
    return $v? $v : '';
}

1;
