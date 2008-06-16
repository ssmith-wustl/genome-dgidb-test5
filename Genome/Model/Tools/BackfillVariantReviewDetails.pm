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
    ],
    has_optional => [
        separation_character =>{
            is => 'String',
            doc => 'character or string that separates the fields in the list',
            default => '|',
        },
        log_file =>{
            is => 'String',
            doc => 'log file containing line no\'s of abnormal snps',
        }
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

sub log{
    my ($self, $input) = @_;
    return unless $input;
    return unless $self->{log_fh};
    chomp $input;
    $self->{log_fh}->print($input."\n");
}

sub execute {
    my $self = shift;

    my $separation_character = $self->separation_character;
    if ($self->log_file){
        my $log_fh = IO::File->new("< ".$self->log_file);
        if ($log_fh){
            $self->{log} = $log_fh;
        }
    }

    eval{

        my $list_reader = Genome::Utility::VariantReviewListReader->new($self->list, $separation_character);

        my $line_no = 0;
        while (my $line_hash = $list_reader->next_line_data()){
            $line_no++;
            next if $line_hash->{header};

            my @current_members = Genome::VariantReviewDetail->get( begin_position => $line_hash->begin_position, chromosome => $line_hash->chromosome, end_position => $line_hash->end_position);
            if (@current_members != 1 ){
                $self->log(scalar @current_members." results for variant @ ".$line_hash->chromosome." ".$line_hash->begin_position." ".$line_hash->end_position.". Not processing, line $line_no");
                next;
            }
            my $current_member = shift @current_members;
            if ($current_member){
                foreach my $column_name ($list_reader->db_columns){
                    if ( $line_hash->{$column_name} ){
                        if ($current_member->$column_name){
                            $self->log("inequal entries for column $column_name, line $line_no") unless $current_member->$column_name eq $line_hash->{$column_name};
                            }else{
                                $current_member->$column_name($line_hash->{$column_name} );
                            }
                        }
                    }
                }
            }  
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
