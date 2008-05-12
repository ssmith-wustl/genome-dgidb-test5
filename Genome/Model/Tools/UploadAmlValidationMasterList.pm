package Genome::Model::Tools::UploadAmlValidationMasterList;

use strict;
use warnings;
use Data::Dumper;
use IO::File;
use Genome::VariantReviewDetail;
use Genome::VariantReviewListFilter;
use Genome::VariantReviewListMember;
use Genome::VariantReviewList;

use above "Genome";

UR::Object::Type->define(
    class_name => __PACKAGE__, is => 'Command',
    has => [
        input => { is => 'String',
        doc => 'Master csv to import'
    },
    ]
);

sub execute {
    my $self = shift;

    my $fh = IO::File->new("< ".$self->input);
    my %ph; #position hash
    my $current_header;

    my $total;
    while (my $line = $fh->getline){
        chomp $line;
        if ($line =~ /^"List"/){
            $current_header = $line;
            next;
        }else{
            my $current_line = $line;
            my @data = split('\|', $line);
            my ($list, $finisher, $venter_watson, $dbsnp, $gene, $chromosome, $begin_position, $end_position, $validate, $notes, $variant_allele) = @data[0..10];

            my ($validation_finisher, $manual_genotype_normal, $manual_genotype_tumor, $manual_genotype_relapse, $somatic_status, $comment) = @data[59,64];

            foreach ($list, $finisher, $venter_watson, $dbsnp, $gene, $chromosome, $begin_position, $end_position, $validate, $notes, $variant_allele, $validation_finisher, $manual_genotype_normal, $manual_genotype_tumor, $manual_genotype_relapse, $somatic_status, $comment){
                $_ =~ s/"//g if $_;
            }

            if ($begin_position){

                $total++;

                my $review_list = Genome::VariantReviewList->get(name => $list);
                unless ($review_list){
                    $review_list = Genome::VariantReviewList->create(name => $list);
                    my $review_list_filter = Genome::VariantReviewListFilter->create(filter_name => $list, list_id => $review_list->id);
                }

                my $list_id = $review_list->id;

                my $current_member = Genome::VariantReviewDetail->get(begin_position => $begin_position, chromosome => $chromosome);
                if ($current_member ){
                    if ($self->vtest($current_member->insert_sequence_allele1) ne $variant_allele){
                        foreach( ['genes', $gene],  ['finisher', $finisher],  ['insert_seqeuence_allele1', $variant_allele], ['supporting_dbs', $dbsnp],  ['supporting_samples',$venter_watson] ){
                            my ($col_name, $var) = @$_;
                            my $new_val = $self->vtest($current_member->$col_name);
                            $new_val.=', ' if $new_val;
                            $new_val.= $var;
                        }
                    }

                    $current_member->notes( $self->vtest($current_member->notes) . "$current_line|\n" );
                }else{
                    $current_member = Genome::VariantReviewDetail->create(
                        begin_position          => $begin_position,
                        chromosome              => $chromosome,
                        end_position            => $end_position,
                        finisher                => $finisher,
                        genes                   => $gene,
                        notes                   => $notes,
                        pass_manual_review      => $validate,
                        report_data             => $current_line,
                        report_header           => $current_header,
                        supporting_dbs          => $dbsnp,
                        supporting_samples      => $venter_watson,
                        variant_type            => 'S',
                        delete_sequence         => 'X',
                        insert_sequence_allele1 => $variant_allele,
                        pass_3730_validation    => $validation_finisher, #somatic status

                        #rgg_id                  => ?,
                        #roi_seq_id              => ?,
                        #sample_name             => ?,
                        #variant_seq_id          => ?,
                    );
                }
                my $member_id = $current_member->id;
                my $review_list_member = Genome::VariantReviewListMember->get_or_create(
                    list_id => $list_id,
                    member_id => $member_id,
                );
            }
        }
    }

#report on multiple positions
    return 1;
}

sub vtest{
    my ($self, $v) = @_;
    return $v? $v : '';
}


1;
