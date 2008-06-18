package Genome::Model::Tools::BackfillVariantReviewDetails;

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
            doc => 'list to backfill from', 
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
    return "Backfills AML lists to db";
}

sub help_synopsis{
    return "gt backfill-variant-review-details --list <list> --logfile <log file for abnormal backups> --separation_char <char>";
}

sub help_detail{
    return "Backfills data, this should not be run routinely";
}

sub log{
    my ($self, $input) = @_;
    return unless $input;
    chomp $input;
    print $input."\n";
    return unless $self->{log_fh};
    $self->{log_fh}->print($input."\n");
}

sub execute {
    my $self = shift;

    my $separation_character = $self->separation_character;
    if ($self->log_file){
        my $log_fh = IO::File->new("> ".$self->log_file);
        if ($log_fh){
            $self->{log_fh} = $log_fh;
        }else{
            $self->log("Can't open log file, no logging will occur!");
        }
    }
    $self->log("Backfilling variant_review_detail from file ".$self->list);

    eval{

        my $list_reader = Genome::Utility::VariantReviewListReader->new($self->list, $separation_character);

        my $line_no = 0;
        while (my $line_hash = $list_reader->next_line_data()){
            last unless $line_hash;
            $line_no++;
            next if $line_hash->{header};

            my @current_members = Genome::VariantReviewDetail->get( begin_position => $line_hash->{begin_position}, chromosome => $line_hash->{chromosome}, end_position => $line_hash->{end_position});
            if (@current_members > 1 ){
                $self->log(scalar @current_members." results for variant @ ".$line_hash->{chromosome}." ".$line_hash->{begin_position}." ".$line_hash->{end_position}.". Not processing, line $line_no");
                next;
            }
            my $current_member = shift @current_members;
            if ($current_member){
                if ($current_member->data_needed  and $current_member->data_needed eq 'X'){
                    $current_member->data_needed('Z');
                }
                foreach my $column_name ($list_reader->db_columns){
                    if ( $line_hash->{$column_name} ){
                        if ($current_member->$column_name){
                            $self->log("inequal entries for column $column_name(db:".$current_member->$column_name.", backfill_list:".$line_hash->{$column_name}.") @ ".$line_hash->{chromosome}." ".$line_hash->{begin_position}." ".$line_hash->{end_position}.", line $line_no") unless $current_member->$column_name eq $line_hash->{$column_name};
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
